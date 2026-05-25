
run-modules() {
  local modules_path="$1"

  [ -d "$modules_path" ] || die "Module path '$modules_path' not found!"

  for module in $modules_path/*.sh; do 
    [[ -e "$module" ]] || continue
    info "$module"
  done
}
