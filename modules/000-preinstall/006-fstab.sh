#!/usr/bin/env bash

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
info "fstab written. Review /mnt/etc/fstab if needed."
