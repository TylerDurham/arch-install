#!/usr/bin/env bash
if [ -z "$SCRIPT_DIR" ]; then
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

# =============================================================================
# LOCALE
# =============================================================================

info "Configuring locale..."
# Uncomment the desired locale in locale.gen
sed -i "s/^#\(${LOCALE} \)/\1/" /etc/locale.gen
# Also ensure en_US.UTF-8 is enabled as a fallback
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
