#!/usr/bin/env bash


# =============================================================================
# TIMEZONE & CLOCK
# =============================================================================

info "Setting timezone to ${TIMEZONE}..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
