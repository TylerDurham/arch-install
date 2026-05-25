#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    source "$(git rev-parse --show-toplevel)/require.sh" io defaults
fi

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

# Build an array of available disks (excluding partitions/loops)
mapfile -t DISKS < <(lsblk -dpno NAME,SIZE,MODEL | grep -E "^/dev/(nvme|sd|vd)")

info "Available disks:"
select CHOICE in "${DISKS[@]}"; do
    [[ -n "${CHOICE}" ]] && break
    warn "Invalid selection, try again."
done

# Extract just the device path (first column)
DISK=$(echo "${CHOICE}" | awk '{print $1}')

[[ -b "${DISK}" ]] \
  && info "Disk ${DISK} found! Proceeding..." \
  || die "Disk ${DISK} not found. Check your CONFIG."

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
