#!/usr/bin/env bash
set -euo pipefail

exec 9> "${XDG_RUNTIME_DIR:-/tmp}/moxi-screen-lock-${UID}.lock"
flock -n 9 || exit 0

# Hyprlock returns after authentication; reapply the saved desktop background.
hyprlock "$@"
"$(dirname -- "${BASH_SOURCE[0]}")/wallpaper-restore.sh"
