#!/usr/bin/env bash

if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  PARENT_DIR=$(dirname $SCRIPT_DIR)
  source $SCRIPT_DIR/common.sh
fi

# =============================================================================
# PASS VARIABLES TO CHROOT SCRIPT
# =============================================================================

directory="arch-install" # $(basename $SCRIPT_DIR)
path="/mnt/root/$directory/install_config.env"

info "Writing config for chroot stage to '$path'..."
exit 0
cat > /mnt/root/$directory/install_config.env <<EOF
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

cp -r $SCRIPT_DIR/ /mnt/root/

arch-chroot /mnt bash "/mnt/root/install CHROOT"
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

