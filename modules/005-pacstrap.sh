#!/usr/bin/env bash

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

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
info "fstab written. Review /mnt/etc/fstab if needed."

