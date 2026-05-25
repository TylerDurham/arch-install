#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    source "$(git rev-parse --show-toplevel)/require.sh" io
fi

PACKAGES=(
    base 
    base-devel 
    bash-completion
    btrfs-progs 
    cryptsetup
    dhcpcd 
    efibootmgr 
    git 
    iwd 
    limine 
    linux 
    linux-firmware
    man
    networkmanager
    openssh
    sudo
    terminus-font
    vim 
)

# =============================================================================
# PACSTRAP
# =============================================================================

info "Syncing pacman databases..."
pacman -Syy

info "Installing base system (this may take a while)..."
pacstrap -K /mnt "${PACKAGES[@]}"

