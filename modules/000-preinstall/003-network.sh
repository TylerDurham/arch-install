#!/usr/bin/env bash

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

info "Checking network connectivity..."
ping -c 1 -W 3 archlinux.org &>/dev/null || die "No internet access. Connect first (e.g. iwctl)."
info "Network OK."
