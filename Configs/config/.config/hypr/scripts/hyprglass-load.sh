#!/usr/bin/env bash
set -euo pipefail

plugin="/etc/hypr/hyprglass.so"
guard="${XDG_RUNTIME_DIR:-/tmp}/moxi-hyprglass-tried"
log="${HOME}/.cache/moxi-hyprglass.log"

[ -f "$plugin" ] || exit 0
[ -e "$guard" ] && exit 0

mkdir -p "$(dirname "$log")"
exec >>"$log" 2>&1

printf '\n[%s] loading hyprglass\n' "$(date '+%F %T')"

touch "$guard"
sleep 2

if ! hyprctl plugin load "$plugin"; then
	printf 'plugin load failed\n'
	exit 0
fi

sleep 2
hyprctl reload || true
sleep 1

if hyprctl plugin list 2>/dev/null | grep -q hyprglass; then
	printf 'hyprglass active\n'
	rm -f "$guard"
fi
