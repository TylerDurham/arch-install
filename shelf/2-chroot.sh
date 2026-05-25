#!/usr/bin/env bash
# =============================================================================
# Arch Linux Chroot Script
# Stage 2: Runs inside arch-chroot /mnt
#
# Sets up: locale, timezone, users, mkinitcpio, Limine bootloader, services
#
# Usage (after running 1-preinstall.sh):
#   arch-chroot /mnt
#   bash /root/2-chroot.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# LOAD CONFIG FROM STAGE 1 (or set manually if running standalone)
# =============================================================================

CONFIG_FILE="/root/install_config.env"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    echo "[INFO]  Loaded config from ${CONFIG_FILE}"
else
    echo "[WARN]  Config file not found. Using defaults — edit this script!"
    DISK="/dev/nvme0n1"
    PART_ESP="/dev/nvme0n1p1"
    PART_SYS="/dev/nvme0n1p2"
    LUKS_UUID=""          # REQUIRED — run: cryptsetup luksUUID /dev/nvme0n1p2
    HOSTNAME="arch"
    TIMEZONE="America/Chicago"
    LOCALE="en_US.UTF-8"
    KEYMAP="us"
    FONT="ter-132b"
    USERNAME="tyler"
fi

# =============================================================================
# HELPERS
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ -n "${LUKS_UUID}" ]] || die "LUKS_UUID is not set. Cannot configure bootloader."

# =============================================================================
# TIMEZONE & CLOCK
# =============================================================================

info "Setting timezone to ${TIMEZONE}..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# =============================================================================
# LOCALE
# =============================================================================

info "Configuring locale..."
# Uncomment the desired locale in locale.gen
sed -i "s/^#\(${LOCALE} \)/\1/" /etc/locale.gen
# Also ensure en_US.UTF-8 is enabled as a fallback
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# =============================================================================
# CONSOLE KEYMAP & FONT
# =============================================================================

info "Setting console keymap and font..."
{
    echo "KEYMAP=${KEYMAP}"
    echo "FONT=${FONT}"
} > /etc/vconsole.conf

# =============================================================================
# HOSTNAME
# =============================================================================

info "Setting hostname to ${HOSTNAME}..."
echo "${HOSTNAME}" > /etc/hostname

# =============================================================================
# ROOT PASSWORD
# =============================================================================

info "Set the root password:"
passwd

# =============================================================================
# USER ACCOUNT
# =============================================================================

info "Creating user account: ${USERNAME}..."
useradd -mG wheel "${USERNAME}"

info "Set password for ${USERNAME}:"
passwd "${USERNAME}"

info "Enabling sudo for wheel group..."
# Uncomment the %wheel ALL=(ALL:ALL) ALL line
sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers

# Verify the change took effect
grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers \
    || die "Failed to enable wheel group in sudoers!"

# =============================================================================
# MKINITCPIO
# =============================================================================

info "Configuring mkinitcpio..."

# Add btrfs to MODULES
sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
sed -i 's/^MODULES=(\(.*\))/MODULES=(btrfs \1)/' /etc/mkinitcpio.conf

# Add /usr/bin/btrfs to BINARIES
sed -i 's|^BINARIES=()|BINARIES=(/usr/bin/btrfs)|' /etc/mkinitcpio.conf
sed -i 's|^BINARIES=(\(.*\))|BINARIES=(/usr/bin/btrfs \1)|' /etc/mkinitcpio.conf

# Insert 'encrypt' hook after 'block' and before 'filesystems'
sed -i 's/\(block \)\(filesystems\)/\1encrypt \2/' /etc/mkinitcpio.conf

info "mkinitcpio.conf HOOKS line:"
grep "^HOOKS=" /etc/mkinitcpio.conf

info "Generating initramfs..."
mkinitcpio -P

# =============================================================================
# LIMINE BOOTLOADER
# =============================================================================

info "Installing Limine bootloader..."
mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/

info "Creating NVRAM entry for Limine..."
efibootmgr --create \
    --disk "${DISK}" \
    --part 1 \
    --label "Arch Linux Limine Bootloader" \
    --loader '\EFI\limine\BOOTX64.EFI' \
    --unicode

info "Writing Limine configuration..."
LIMINE_CONF="/boot/EFI/limine/limine.conf"

cat > "${LIMINE_CONF}" <<EOF
timeout: 3

/Arch Linux
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: quiet cryptdevice=UUID=${LUKS_UUID}:root root=/dev/mapper/root rw rootflags=subvol=@ rootfstype=btrfs
    module_path: boot():/initramfs-linux.img

/Arch Linux (fallback)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: quiet cryptdevice=UUID=${LUKS_UUID}:root root=/dev/mapper/root rw rootflags=subvol=@ rootfstype=btrfs
    module_path: boot():/initramfs-linux-fallback.img
EOF

info "Limine config written to ${LIMINE_CONF}"

# =============================================================================
# ENABLE SERVICES
# =============================================================================

info "Enabling systemd services..."

SERVICES=(
    NetworkManager
    dhcpcd
    iwd
    systemd-networkd
    systemd-resolved
    bluetooth
    cups
    avahi-daemon
    firewalld
    acpid
    reflector.timer
)

for svc in "${SERVICES[@]}"; do
    systemctl enable "${svc}" && info "  Enabled: ${svc}" \
        || warn "  Could not enable: ${svc} (may be missing)"
done

# =============================================================================
# PACMAN HOOK FOR LIMINE
# =============================================================================

info "Installing pacman hook for Limine auto-update..."
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/99-limine.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = limine

[Action]
Description = Deploying Limine after upgrade...
When = PostTransaction
Exec = /usr/bin/cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
EOF

# =============================================================================
# DONE
# =============================================================================

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Stage 2 complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo
echo -e "  Next steps:"
echo -e "    ${YELLOW}exit${NC}                 (leave chroot)"
echo -e "    ${YELLOW}umount -R /mnt${NC}       (unmount filesystems)"
echo -e "    ${YELLOW}cryptsetup close root${NC} (close LUKS container)"
echo -e "    ${YELLOW}reboot${NC}               (remove install media!)"
echo
echo -e "  After first boot, run Stage 3 as your user:"
echo -e "    ${YELLOW}bash /root/3-postinstall.sh${NC}"
echo
