#!/usr/bin/env bash

select-timezone() {
  ZONEINFO=/usr/share/zoneinfo

  # Step 1: pick a region (top-level directories only)
  regions=$(find "$ZONEINFO" -mindepth 1 -maxdepth 1 \
      -type d \
      -not -name 'posix' \
      -not -name 'right' \
      | sed "s|$ZONEINFO/||" \
      | sort)

  region=$(echo "$regions" | fzf --prompt="Region: " --height=40% --layout=reverse)
  [[ -z "$region" ]] && { echo "Cancelled."; exit 1; }

  # Step 2: pick a city/zone within that region
  zone=$(find "$ZONEINFO/$region" -type f \
      | sed "s|$ZONEINFO/||" \
      | sort \
      | fzf --prompt="Zone: " --height=40% --layout=reverse)

  [[ -z "$zone" ]] && { echo "Cancelled."; exit 1; }

  echo "$zone"
}
