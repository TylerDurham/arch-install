# Arch Linux Install Scripts
### BTRFS + LUKS2 + Limine + Snapper + Hyprland

Automated scripts based on [yovko's install notes](https://gist.github.com/yovko/512326b904d120f3280c163abfbcb787).

---

## Overview

| Script | When to run | What it does |
|---|---|---|
| `1-preinstall.sh` | From live ISO | Partitioning, LUKS2, BTRFS subvolumes, pacstrap |
| `2-chroot.sh` | Inside arch-chroot | Locale, users, mkinitcpio, Limine, services |
| `3-postinstall.sh` | After first boot | Swap/hibernate, Snapper, yay, Hyprland, firmware |

---

## Usage

### Prerequisites

- Boot from the [official Arch Linux ISO](https://archlinux.org/download/)
- Connect to the internet:
  ```
  iwctl station <device> connect <SSID>
  ```
- Download the scripts (e.g. via git or curl):
  ```
  curl -LO https://your-host/arch-install/1-preinstall.sh
  curl -LO https://your-host/arch-install/2-chroot.sh
  curl -LO https://your-host/arch-install/3-postinstall.sh
  chmod +x *.sh
  ```

---

### Stage 1 — Pre-install (from live ISO)

**Edit the CONFIG section at the top of `1-preinstall.sh`:**

```bash
DISK="/dev/nvme0n1"         # Your target disk
USERNAME="yourname"         # Your username
TIMEZONE="America/Chicago"  # Your timezone
UCODE="intel-ucode"         # or amd-ucode
```

Then run:
```bash
bash 1-preinstall.sh
```

When complete:
```bash
arch-chroot /mnt
bash /root/2-chroot.sh
```

---

### Stage 2 — Chroot setup

Config is automatically loaded from Stage 1. The script will prompt you interactively for:
- Root password
- Your user password

---

### Stage 3 — Post-install (after first boot)

Log in as your user, then:
```bash
bash /root/3-postinstall.sh
```

**Edit the CONFIG section if needed:**
```bash
SWAP_SIZE="32g"             # Match your RAM
INSTALL_HYPRLAND=true
INSTALL_INTEL_VIDEO=true    # false for AMD/Nvidia
SETUP_SNAPPER=true
```

---

## What gets installed

### Base system (Stage 1)
- LUKS2-encrypted BTRFS root with subvolumes: `@`, `@home`, `@var_log`, `@var_cache`, `@snapshots`
- zstd compression, noatime mount options
- Full package set including pipewire, NetworkManager, bluetooth, cups, firewalld

### Bootloader (Stage 2)
- [Limine](https://codeberg.org/Limine/Limine) with UEFI NVRAM entry
- Pacman hook to auto-update Limine on upgrade

### Post-install (Stage 3)
- BTRFS swapfile with hibernate support (`resume=` kernel params)
- [Snapper](http://snapper.io) with `limine-snapper-sync` (bootable snapshots)
- `snap-pac` (auto-snapshot on pacman transactions)
- `yay` AUR helper
- `fwupd` automatic firmware updates
- [Hyprland](https://hyprland.org) with seatd, UWSM, wofi, mako, kitty

---

## Notes & Caveats

- **Disk target** — Scripts default to `/dev/nvme0n1`. Always verify with `lsblk` first.
- **CPU microcode** — Change `intel-ucode` to `amd-ucode` in Stage 1 for AMD systems.
- **Swap size** — `SWAP_SIZE` should equal your RAM for full hibernate support.
- **Resume offset** — The script attempts to determine this automatically via
  `btrfs inspect-internal map-swapfile`. If it shows `FIXME`, run it manually after boot.
- **LUKS UUID** — Passed automatically between stages. If running stages independently,
  get it with: `cryptsetup luksUUID /dev/nvme0n1p2`
- **Snapper** requires `limine-snapper-sync` and `limine-mkinitcpio-hook` from the AUR —
  these are installed automatically via yay in Stage 3.
- The scripts do **not** configure WiFi profiles post-install — run `iwctl` again after reboot
  or use `nmtui` if using NetworkManager.
