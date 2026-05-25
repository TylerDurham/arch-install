#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # We're not being sourced from another script... load our modules
    ROOT_DIR="$(git rev-parse --show-toplevel)"
    source "$ROOT/require.sh" io
    PARENT_DIR=$ROOT_DIR
fi

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  PARENT_DIR=$(dirname $SCRIPT_DIR)
  source $SCRIPT_DIR/common.sh
fi

# =============================================================================
# PASS VARIABLES TO CHROOT SCRIPT
# =============================================================================

directory=$(basename "$SCRIPT_DIR")

info "Copying installer tree to /mnt/root/$directory ..."
cp -r "$SCRIPT_DIR" /mnt/root/

info "Writing config to /mnt/root/$directory/install_config.env ..."
cat > "/mnt/root/$directory/install_config.env" <<EOF
DISK="${DISK}"
PART_ESP="${PART_ESP}"
PART_SYS="${PART_SYS}"
LUKS_UUID="${LUKS_UUID}"
HOSTNAME="${HOSTNAME}"
TIMEZONE="${TIMEZONE}"
LOCALE="${LOCALE}"
KEYMAP="${KEYMAP}"
FONT="${FONT}"
USERNAME="${USERNAME}"
EOF

arch-chroot /mnt bash "/root/$directory/install" CHROOT
exit

# =============================================================================
# DONE
# =============================================================================

echo
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Stage 1 complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo
echo -e "  LUKS UUID saved to: ${YELLOW}/tmp/luks_uuid.txt${NC}"
echo -e "  UUID: ${YELLOW}${LUKS_UUID}${NC}"
echo
echo -e "  Next step — enter chroot and run Stage 2:"
echo -e "    ${YELLOW}arch-chroot /mnt${NC}"
echo -e "    ${YELLOW}bash /root/2-chroot.sh${NC}"
echo

