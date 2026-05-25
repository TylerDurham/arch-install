#!/usr/bin/env bash
# =============================================================================
# Arch Linux Post-Install Script
# Stage 3: Runs after first successful boot into the new system
#
# Sets up: swap/hibernation, Snapper snapshots, yay (AUR helper),
#          additional packages, Hyprland, firmware updates, NTP, TRIM
#
# Usage:
#   Run as your regular user (with sudo access):
#   bash /root/3-postinstall.sh
#   (or copy it to your home directory first)
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIG — Edit to match your system
# =============================================================================

SWAP_SIZE="32g"               # Size of swapfile (match your RAM size)
TIMEZONE="America/Chicago"    # Should match what you set in Stage 2
MACHINE_ID=$(cat /etc/machine-id)

# Set to true/false to enable/disable optional sections
INSTALL_HYPRLAND=true
INSTALL_INTEL_VIDEO=true      # Set false for AMD/Nvidia
INSTALL_LIBREOFFICE=true
SETUP_SNAPPER=true
SETUP_FIRMWARE_UPDATES=true

# =============================================================================
# HELPERS
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
confirm() {
    read -rp "$1 [y/N] " ans
    [[ "${ans,,}" == "y" ]]
}

# Ensure we're not running as root
[[ $EUID -ne 0 ]] || die "Run this script as your regular user, not root."

# =============================================================================
# NTP / TIME SYNC
# =============================================================================

info "Enabling NTP time sync..."
sudo timedatectl set-ntp true
timedatectl status

# =============================================================================
# ADDITIONAL PACKAGES
# =============================================================================

info "Installing additional packages..."
sudo pacman -Syu --needed \
    wget htop gvfs gvfs-smb inetutils imagemagick usbutils \
    easyeffects openbsd-netcat nss-mdns bat zip unzip \
    brightnessctl xdg-user-dirs \
    noto-fonts nerd-fonts ttf-jetbrains-mono \
    firefox thunderbird

if [[ "${INSTALL_LIBREOFFICE}" == true ]]; then
    info "Installing LibreOffice..."
    sudo pacman -Syu --needed libreoffice-fresh
fi

if [[ "${INSTALL_INTEL_VIDEO}" == true ]]; then
    info "Installing Intel video drivers..."
    sudo pacman -Syu --needed intel-media-driver mesa vulkan-intel
fi

# =============================================================================
# YAY (AUR HELPER)
# =============================================================================

info "Installing yay AUR helper..."
if command -v yay &>/dev/null; then
    info "yay is already installed, skipping."
else
    YAY_BUILD_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "${YAY_BUILD_DIR}/yay"
    (cd "${YAY_BUILD_DIR}/yay" && makepkg -si --noconfirm)
    rm -rf "${YAY_BUILD_DIR}"
    info "yay installed successfully."
fi

# =============================================================================
# TRIM SUPPORT
# =============================================================================

info "Enabling periodic SSD TRIM..."
info "Checking TRIM support:"
lsblk --discard

sudo systemctl enable --now fstrim.timer
info "TRIM timer enabled (runs weekly)."

# =============================================================================
# SWAP & HIBERNATION
# =============================================================================

info "Setting up swap file for hibernation..."

# Get LUKS UUID (the mapped root device)
ROOT_UUID=$(findmnt -no UUID /)
info "Root filesystem UUID: ${ROOT_UUID}"

# Create swap subvolume if it doesn't exist
if [[ ! -d /swap ]]; then
    sudo btrfs subvolume create /swap
    info "Created /swap BTRFS subvolume."
fi

if [[ ! -f /swap/swapfile ]]; then
    info "Creating ${SWAP_SIZE} swapfile (this may take a moment)..."
    sudo btrfs filesystem mkswapfile --size "${SWAP_SIZE}" --uuid clear /swap/swapfile
    sudo swapon -p 0 /swap/swapfile
    info "Swapfile activated."

    info "Adding swapfile to /etc/fstab..."
    echo '/swap/swapfile none swap defaults,pri=0 0 0' | sudo tee -a /etc/fstab
else
    info "Swapfile already exists at /swap/swapfile, skipping creation."
fi

# Get resume_offset for the swapfile
RESUME_OFFSET=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile 2>/dev/null || true)
if [[ -z "${RESUME_OFFSET}" ]]; then
    warn "Could not determine resume_offset automatically."
    warn "Run manually: sudo btrfs inspect-internal map-swapfile -r /swap/swapfile"
    RESUME_OFFSET="FIXME"
fi

SWAP_UUID=$(findmnt -no UUID -T /swap/swapfile)
info "Swap UUID: ${SWAP_UUID}"
info "Resume offset: ${RESUME_OFFSET}"

# Add resume hook to mkinitcpio.conf
info "Adding 'resume' hook to mkinitcpio.conf..."
if ! grep -q "resume" /etc/mkinitcpio.conf; then
    # Insert 'resume' after 'filesystems' and before 'fsck'
    sudo sed -i 's/\(filesystems \)\(fsck\)/\1resume \2/' /etc/mkinitcpio.conf
    info "Added resume hook."
else
    info "resume hook already present."
fi

info "mkinitcpio HOOKS:"
grep "^HOOKS=" /etc/mkinitcpio.conf

sudo mkinitcpio -P

# Update Limine config with resume params
info "Checking Limine configs for resume parameters..."
LIMINE_CONF="/boot/EFI/limine/limine.conf"
LIMINE_MAIN="/boot/limine.conf"

update_limine_resume() {
    local conf_file="$1"
    if [[ -f "${conf_file}" ]] && ! grep -q "resume=" "${conf_file}"; then
        info "Updating ${conf_file} with resume params..."
        sudo sed -i "s|\(rootfstype=btrfs\)|\1 resume=UUID=${SWAP_UUID} resume_offset=${RESUME_OFFSET}|" "${conf_file}"
        info "Updated ${conf_file}"
    elif [[ -f "${conf_file}" ]]; then
        info "Resume params already in ${conf_file}, skipping."
    fi
}

update_limine_resume "${LIMINE_CONF}"
[[ -f "${LIMINE_MAIN}" ]] && update_limine_resume "${LIMINE_MAIN}"

# =============================================================================
# SNAPPER
# =============================================================================

if [[ "${SETUP_SNAPPER}" == true ]]; then
    info "Setting up Snapper..."
    sudo pacman -Syu --needed snapper

    info "Installing limine-snapper-sync from AUR..."
    yay -S --needed --noconfirm limine-snapper-sync limine-mkinitcpio-hook

    # Add btrfs-overlayfs hook to mkinitcpio
    info "Adding btrfs-overlayfs hook..."
    if ! grep -q "btrfs-overlayfs" /etc/mkinitcpio.conf; then
        sudo sed -i 's/\(HOOKS=(.*\))/\1 btrfs-overlayfs)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi

    # Configure Snapper for root
    info "Configuring Snapper root config..."
    if [[ -d /.snapshots ]]; then
        sudo umount /.snapshots 2>/dev/null || true
    fi

    if ! snapper list-configs 2>/dev/null | grep -q "^root"; then
        sudo snapper -c root create-config /
    else
        info "Snapper root config already exists."
    fi

    if ! snapper list-configs 2>/dev/null | grep -q "^home"; then
        sudo snapper -c home create-config /home
    else
        info "Snapper home config already exists."
    fi

    sudo mount -a

    # Tune Snapper: disable timeline, limit snapshots
    for cfg in root home; do
        sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/"${cfg}"
        sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/'         /etc/snapper/configs/"${cfg}"
        sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/"${cfg}"
    done

    # limine-snapper-sync configuration
    LIMINE_DEFAULT="/etc/default/limine"
    if [[ ! -f "${LIMINE_DEFAULT}" ]] && [[ -f /etc/limine-snapper-sync.conf ]]; then
        sudo cp /etc/limine-snapper-sync.conf "${LIMINE_DEFAULT}"
    fi

    if [[ -f "${LIMINE_DEFAULT}" ]]; then
        sudo tee "${LIMINE_DEFAULT}" > /dev/null <<'EOF'
MAX_SNAPSHOT_ENTRIES=5
LIMIT_USAGE_PERCENT=85
ROOT_SNAPSHOTS_PATH="/@snapshots"
EOF
        info "Wrote ${LIMINE_DEFAULT}"
    fi

    # Disable Secure Boot enroll commands if present in sync config
    if [[ -f /etc/limine-snapper-sync.conf ]]; then
        sudo sed -i 's/^\(COMMANDS_BEFORE_SAVE=.*\)/#\1/' /etc/limine-snapper-sync.conf
        sudo sed -i 's/^\(COMMANDS_AFTER_SAVE=.*\)/#\1/'  /etc/limine-snapper-sync.conf
    fi

    # Write /boot/limine.conf with Snapper integration
    info "Writing /boot/limine.conf with Snapper snapshot support..."
    LUKS_UUID=$(sudo cryptsetup luksUUID "$(findmnt -no SOURCE / | sed 's|/dev/mapper/||' | xargs -I{} find /dev/disk/by-id/ -name '*' -exec sh -c 'cryptsetup luksUUID "$1" 2>/dev/null' _ {} \; 2>/dev/null | head -1)" 2>/dev/null || echo "FIXME-LUKS-UUID")

    # Easier fallback: pull from existing limine.conf
    if [[ "${LUKS_UUID}" == "FIXME-LUKS-UUID" ]] && [[ -f "${LIMINE_CONF}" ]]; then
        LUKS_UUID=$(grep -oP 'cryptdevice=UUID=\K[^:]+' "${LIMINE_CONF}" | head -1 || echo "FIXME-LUKS-UUID")
    fi

    sudo tee /boot/limine.conf > /dev/null <<EOF
term_font_scale: 2x2

/+Arch Linux
comment: Arch Linux
comment: machine-id=${MACHINE_ID}

    //Linux
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: quiet cryptdevice=UUID=${LUKS_UUID}:root root=/dev/mapper/root rw rootflags=subvol=@ rootfstype=btrfs resume=UUID=${SWAP_UUID} resume_offset=${RESUME_OFFSET}
    module_path: boot():/initramfs-linux.img

    //Snapshots
EOF

    info "Syncing Limine snapshot entries..."
    sudo limine-snapper-sync || warn "limine-snapper-sync had errors — check manually."
    sudo systemctl enable --now limine-snapper-sync.service || true

    info "Installing snap-pac (auto-snapshot on pacman)..."
    sudo pacman -Syu --needed snap-pac

    info "Snapper setup complete."
fi

# =============================================================================
# FIRMWARE UPDATES
# =============================================================================

if [[ "${SETUP_FIRMWARE_UPDATES}" == true ]]; then
    info "Setting up automatic firmware updates..."
    sudo pacman -Syu --needed fwupd udisks2
    fwupdmgr get-devices   || true
    fwupdmgr refresh       || true
    fwupdmgr get-updates   || true
    if confirm "Apply available firmware updates now?"; then
        fwupdmgr update || true
    fi
    sudo systemctl enable --now fwupd-refresh.timer
fi

# =============================================================================
# HYPRLAND
# =============================================================================

if [[ "${INSTALL_HYPRLAND}" == true ]]; then
    info "Installing Hyprland and related packages..."
    sudo pacman -Syu --needed \
        hyprland nwg-displays xdg-desktop-portal-hyprland \
        swaylock wofi dolphin kitty seatd uwsm libnewt mako \
        greetd-regreet

    yay -S --needed --noconfirm wlogout

    sudo systemctl enable --now seatd.service

    # Create default Hyprland config directory
    HYPR_CONF="${HOME}/.config/hypr"
    mkdir -p "${HYPR_CONF}"

    if [[ ! -f "${HYPR_CONF}/hyprland.conf" ]]; then
        info "Writing example Hyprland config..."
        cat > "${HYPR_CONF}/hyprland.conf" <<'EOF'
# Hyprland configuration
# See https://wiki.hypr.land/Getting-Started/Master-Tutorial/

input {
    kb_layout = us
    # For Bulgarian Phonetic, replace with:
    # kb_layout = us, bg
    # kb_variant = , phonetic
    # kb_options = grp:win_space_toggle
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
}

# Uncomment and adjust for your monitor
# monitorv2 {
#     output = eDP-1
#     mode = 1920x1080@60
#     position = 0x0
#     scale = 1
# }
EOF
        info "Hyprland config written to ${HYPR_CONF}/hyprland.conf"
    else
        info "Hyprland config already exists, skipping."
    fi
fi

# =============================================================================
# XDG USER DIRS
# =============================================================================

info "Setting up XDG user directories..."
xdg-user-dirs-update

# =============================================================================
# DONE
# =============================================================================

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Stage 3 complete! Your system is ready.${NC}"
echo -e "${GREEN}============================================================${NC}"
echo
echo -e "  ${YELLOW}Important — review these if marked FIXME:${NC}"
echo -e "  • LUKS UUID in /boot/limine.conf and /boot/EFI/limine/limine.conf"
echo -e "  • Resume offset: ${YELLOW}${RESUME_OFFSET}${NC}"
echo -e "    Verify with: sudo btrfs inspect-internal map-swapfile -r /swap/swapfile"
echo
echo -e "  ${YELLOW}Useful post-install references:${NC}"
echo -e "  • Arch wiki Hyprland: https://wiki.archlinux.org/title/Hyprland"
echo -e "  • UWSM:               https://wiki.archlinux.org/title/Universal_Wayland_Session_Manager"
echo -e "  • Hyprland tutorial:  https://wiki.hypr.land/Getting-Started/Master-Tutorial/"
echo -e "  • Limine Snapper:     https://wiki.archlinux.org/title/Limine#Snapper_snapshot_integration_for_Btrfs"
echo
echo -e "  Reboot to apply all changes: ${YELLOW}sudo reboot${NC}"
echo
