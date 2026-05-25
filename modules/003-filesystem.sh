#!/usr/bin/env bash

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



