#!/usr/bin/env bash
set -euo pipefail

# Serialize restores so repeated lock/startup events cannot race renderers.
exec 9> "${XDG_RUNTIME_DIR:-/tmp}/moxi-wallpaper-restore-${UID}.lock"
flock -n 9 || exit 0

image=""
if [ -r "${HOME}/.cache/current-wallpaper" ]; then
	IFS= read -r image < "${HOME}/.cache/current-wallpaper" || true
fi

if [ ! -f "$image" ]; then
	image="${HOME}/walls/flowers.png"
fi
[ -f "$image" ] || exit 0

# Background renderers must not inherit the restore lock descriptor.
"$(dirname -- "${BASH_SOURCE[0]}")/wallpaper-set.sh" "$image" --restore 9>&-
