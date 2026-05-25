#!/usr/bin/env bash

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

info "Verifying UEFI boot mode..."
[[ -f /sys/firmware/efi/fw_platform_size ]] || die "Not booted in UEFI mode."
EFI_BITS=$(cat /sys/firmware/efi/fw_platform_size)
info "UEFI ${EFI_BITS}-bit confirmed."
