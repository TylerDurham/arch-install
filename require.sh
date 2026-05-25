#  ██████╗ ███████╗ ██████╗ ██╗   ██╗██╗██████╗ ███████╗
#  ██╔══██╗██╔════╝██╔═══██╗██║   ██║██║██╔══██╗██╔════╝
#  ██████╔╝█████╗  ██║   ██║██║   ██║██║██████╔╝█████╗
#  ██╔══██╗██╔══╝  ██║▄▄ ██║██║   ██║██║██╔══██╗██╔══╝
#  ██║  ██║███████╗╚██████╔╝╚██████╔╝██║██║  ██║███████╗
#  ╚═╝  ╚═╝╚══════╝ ╚══▀▀═╝  ╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝
#
#  Bash module loader — like require(), but for shell scripts.
#
#  Provides load_modules(), which sources .sh files by name from
#  $LIB_DIR (or by explicit path) while guaranteeing each
#  module is loaded at most once per shell session via guard variables.
#
#  Usage:
#    load_modules logging colors utils       # loads from $MY_BASH_LIB_DIR
#    load_modules ./relative/path.sh         # loads by explicit path
#    source require.sh logging colors        # self-executes on source

LIB_DIR=$(git rev-parse --show-toplevel)/modules/lib

load_modules() {
  local module guard file
  for module in "$@"; do
    guard=_LOADED_$(tr -cd '[:alnum:]_-' <<< "$module")
    if [[ "$module" == /* || "$module" == ./* ]]; then
      file="$module"
      # guard="_LOADED_${module//\//_}"; guard="${guard//[.@]/_}"
    else
      # guard="_LOADED_${module//\//_}"; guard="${guard//[.@]/_}"
      file="$LIB_DIR/${module}.sh"
    fi

    [[ -n "${!guard:-}" ]] && continue
    [[ -f "$file" ]] || { echo "module not found: $file" >&2; return 1; }
    source "$file"
    printf -v "$guard" 1
  done
}

load_modules "$@"
