#!/usr/bin/env bash

info "Checking network connectivity..."
ping -c 1 -W 3 archlinux.org &>/dev/null || die "No internet access. Connect first (e.g. iwctl)."
info "Network OK."
