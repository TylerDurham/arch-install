#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    source "$(git rev-parse --show-toplevel)/require.sh" io
fi

info "Verifying UEFI boot mode..."

# Exit if not uefi
[[ -f /sys/firmware/efi/fw_platform_size ]] || die "Not booted in UEFI mode."

# Get uefi size and report back
EFI_BITS=$(cat /sys/firmware/efi/fw_platform_size)

info "UEFI ${EFI_BITS}-bit confirmed."
