#!/usr/bin/env bash

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
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

