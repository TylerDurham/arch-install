# =============================================================================
# HELPERS
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
confirm() {
    read -rp "$1 [y/N] " ans
    [[ "${ans,,}" == "y" ]] || die "Aborted."
}

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
