# ============================================================================= 
# TIMEZONE & CLOCK
# =============================================================================

#!/usr/bin/env bash
if [ -z "$SCRIPT_DIR" ]; then
  # Script is being called by itself... load dependancies
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  source $SCRIPT_DIR/common.sh
fi

if [[ -z "$TIMEZONE" ]]; then
  # Caller has not specified the TIMEZONE. Use our library to get it.
  detect_timezone
fi

# Build path to zoneinfo file
TZ_PATH="/usr/share/zoneinfo/${TIMEZONE}"

# Doesn't exist...
if [[ ! -f "$TZ_PATH" ]]; then
  die "Invalid timezone: '$TIMEZONE'!"
fi

# Save it!
info "Setting timezone to ${TIMEZONE}..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
