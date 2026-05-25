#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    source "$(git rev-parse --show-toplevel)/require.sh" io
fi

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
info "fstab written. Review /mnt/etc/fstab if needed."
