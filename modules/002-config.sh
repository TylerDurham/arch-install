#!/usr/bin/env 

detect_timezone() {
    info "Detecting timezone via IP geolocation..."
    local tz
    tz=$(curl -sf "https://ipapi.co/timezone" 2>/dev/null)
    
    if [[ -n "${tz}" ]] && [[ "${tz}" != *"error"* ]]; then
        info "Detected timezone: ${tz}"
        read -rp "Use '${tz}'? [Y/n] " ans
        if [[ "${ans,,}" != "n" ]]; then
            TIMEZONE="${tz}"
            return
        fi
    else
        warn "Could not auto-detect timezone."
    fi

    # Fallback: manual entry
    read -rp "Enter timezone (e.g. America/Chicago): " TIMEZONE
}

detect_timezone

read -rp "Enter username: " USERNAME
read -rp "Enter computer name: " HOSTNAME

