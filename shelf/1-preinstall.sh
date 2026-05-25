#!/usr/bin/env bash
# =============================================================================
# Arch Linux Pre-Install Script
# Stage 1: Runs from the live Arch ISO
#
# Sets up: disk partitioning, LUKS2 encryption, BTRFS subvolumes, pacstrap
#
# Usage:
#   1. Boot from Arch Linux ISO
#   2. Connect to the internet (e.g. `iwctl station wlan0 connect SSID`)
#   3. Edit the CONFIG section below to match your system
#   4. Run: bash 1-preinstall.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIG — Edit these before running
# =============================================================================

DISK="/dev/nvme0n1"           # Target disk (check with lsblk)
ESP_SIZE="2049MiB"            # EFI system partition size (2GB recommended)
HOSTNAME="arch"               # System hostname
TIMEZONE="America/Chicago"    # Timezone (timedatectl list-timezones)
LOCALE="en_US.UTF-8"          # Primary locale
KEYMAP="us"                   # Console keymap
FONT="ter-132b"               # Console font (optional, comment out if not needed)
USERNAME="tyler"              # Your username
UCODE="intel-ucode"           # intel-ucode or amd-ucode

# Packages to install via pacstrap
PACKAGES=(
    base base-devel linux linux-firmware
    git vim btrfs-progs efibootmgr limine cryptsetup
    dhcpcd iwd networkmanager reflector bash-completion
    avahi acpi acpi_call acpid alsa-utils
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber sof-firmware
    firewalld bluez bluez-utils cups util-linux terminus-font
    openssh man sudo rsync
    "${UCODE}"
)

# =============================================================================
# HELPERS
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
confirm() {
    read -rp "$1 [y/N] " ans
    [[ "${ans,,}" == "y" ]] || die "Aborted."
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

info "Verifying UEFI boot mode..."
[[ -f /sys/firmware/efi/fw_platform_size ]] || die "Not booted in UEFI mode."
EFI_BITS=$(cat /sys/firmware/efi/fw_platform_size)
info "UEFI ${EFI_BITS}-bit confirmed."

info "Checking network connectivity..."
ping -c 1 -W 3 archlinux.org &>/dev/null || die "No internet access. Connect first (e.g. iwctl)."
info "Network OK."

[[ -b "${DISK}" ]] || die "Disk ${DISK} not found. Check your CONFIG."

warn "This will DESTROY ALL DATA on ${DISK}!"
lsblk "${DISK}"
confirm "Proceed with installation on ${DISK}?"

# =============================================================================
# DISK SETUP
# =============================================================================

info "Wiping existing partition table on ${DISK}..."
sgdisk --zap-all "${DISK}"

info "Creating GPT partition layout..."
parted --script "${DISK}" \
    mklabel gpt \
    mkpart ESP fat32 1MiB "${ESP_SIZE}" \
    set 1 esp on \
    mkpart Linux btrfs "$((${ESP_SIZE%MiB} + 1))MiB" 100%

# Derive partition paths (handles both /dev/nvme0n1 and /dev/sda style)
if [[ "${DISK}" == *nvme* ]] || [[ "${DISK}" == *mmcblk* ]]; then
    PART_ESP="${DISK}p1"
    PART_SYS="${DISK}p2"
else
    PART_ESP="${DISK}1"
    PART_SYS="${DISK}2"
fi

info "Partitions created: ESP=${PART_ESP}  System=${PART_SYS}"

# =============================================================================
# FORMAT ESP
# =============================================================================

info "Formatting ESP as FAT32..."
mkfs.fat -F 32 "${PART_ESP}"

# =============================================================================
# LUKS2 ENCRYPTION
# =============================================================================

info "Setting up LUKS2 encryption on ${PART_SYS}..."
warn "You will be prompted to set and confirm your disk encryption passphrase."
cryptsetup luksFormat "${PART_SYS}"

info "Opening LUKS container..."
cryptsetup open "${PART_SYS}" root

LUKS_UUID=$(cryptsetup luksUUID "${PART_SYS}")
info "LUKS UUID: ${LUKS_UUID}"
info "Save this UUID — you will need it for the bootloader config!"
echo "${LUKS_UUID}" > /tmp/luks_uuid.txt

# =============================================================================
# BTRFS SETUP
# =============================================================================

info "Formatting LUKS container as BTRFS..."
mkfs.btrfs /dev/mapper/root

info "Mounting BTRFS to create subvolumes..."
mount /dev/mapper/root /mnt

info "Creating BTRFS subvolumes..."
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@snapshots

info "Unmounting and remounting subvolumes with options..."
umount /mnt

BTRFS_OPTS="compress=zstd:1,noatime"
mount -o "${BTRFS_OPTS},subvol=@"           /dev/mapper/root /mnt
mount --mkdir -o "${BTRFS_OPTS},subvol=@home"      /dev/mapper/root /mnt/home
mount --mkdir -o "${BTRFS_OPTS},subvol=@var_log"   /dev/mapper/root /mnt/var/log
mount --mkdir -o "${BTRFS_OPTS},subvol=@var_cache" /dev/mapper/root /mnt/var/cache
mount --mkdir -o "${BTRFS_OPTS},subvol=@snapshots" /dev/mapper/root /mnt/.snapshots
mount --mkdir "${PART_ESP}" /mnt/boot

info "Filesystem layout:"
lsblk "${DISK}"

# =============================================================================
# PACSTRAP
# =============================================================================

info "Syncing pacman databases..."
pacman -Syy

info "Installing base system (this may take a while)..."
pacstrap -K /mnt "${PACKAGES[@]}"

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
info "fstab written. Review /mnt/etc/fstab if needed."

# =============================================================================
# PASS VARIABLES TO CHROOT SCRIPT
# =============================================================================

info "Writing config for chroot stage..."
cat > /mnt/root/install_config.env <<EOF
DISK="${DISK}"
PART_ESP="${PART_ESP}"
PART_SYS="${PART_SYS}"
LUKS_UUID="${LUKS_UUID}"
HOSTNAME="${HOSTNAME}"
TIMEZONE="${TIMEZONE}"
LOCALE="${LOCALE}"
KEYMAP="${KEYMAP}"
FONT="${FONT}"
USERNAME="${USERNAME}"
EOF

# Copy the chroot script into the new system
cp "$(dirname "$0")/2-chroot.sh" /mnt/root/2-chroot.sh
chmod +x /mnt/root/2-chroot.sh

info "Copying post-install script..."
cp "$(dirname "$0")/3-postinstall.sh" /mnt/root/3-postinstall.sh
chmod +x /mnt/root/3-postinstall.sh

# =============================================================================
# DONE
# =============================================================================

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Stage 1 complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo
echo -e "  LUKS UUID saved to: ${YELLOW}/tmp/luks_uuid.txt${NC}"
echo -e "  UUID: ${YELLOW}${LUKS_UUID}${NC}"
echo
echo -e "  Next step — enter chroot and run Stage 2:"
echo -e "    ${YELLOW}arch-chroot /mnt${NC}"
echo -e "    ${YELLOW}bash /root/2-chroot.sh${NC}"
echo
