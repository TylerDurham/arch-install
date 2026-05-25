#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    source "$(git rev-parse --show-toplevel)/require.sh" io
fi

info "Checking network connectivity..."
ping -c 1 -W 3 archlinux.org &>/dev/null || die "No internet access. Connect first (e.g. iwctl)."
info "Network OK."
