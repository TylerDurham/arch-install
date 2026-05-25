#!/usr/bin/env bash
if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

# =============================================================================
# CONSOLE KEYMAP & FONT
# =============================================================================

info "Setting console keymap and font..."
{
    echo "KEYMAP=${KEYMAP:-US}"
    echo "FONT=${FONT}"
} > /etc/vconsole.conf
