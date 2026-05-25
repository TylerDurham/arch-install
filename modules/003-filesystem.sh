#!/usr/bin/env bash

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




