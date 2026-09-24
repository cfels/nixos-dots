#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
[ -n "$image" ] || exit 1
[ -f "$image" ] || exit 1

resolve() {
	local name="$1"
	local path

	path="$(command -v "$name" 2>/dev/null || true)"
	if [ -n "$path" ]; then
		printf '%s' "$path"
		return 0
	fi

	path="$(ls -d /nix/store/*-"${name}"-[0-9]*/bin/"${name}" 2>/dev/null | sort -V | tail -n 1 || true)"
	if [ -n "$path" ]; then
		printf '%s' "$path"
		return 0
	fi

	return 1
}

tool="$(resolve awww || resolve swww)" || exit 1

daemon=""
if daemon="$(resolve awww-daemon)"; then
	:
elif daemon="$(resolve swww-daemon)"; then
	:
else
	daemon=""
fi

if ! pgrep -f "awww-daemon|swww-daemon" >/dev/null 2>&1; then
	[ -n "$daemon" ] || exit 1
	setsid "$daemon" >/dev/null 2>&1 < /dev/null &
	sleep 0.5
fi

"$tool" img "$image" \
	--transition-type grow \
	--transition-pos center \
	--transition-duration 1.2 \
	--transition-fps 60

mkdir -p "${HOME}/.cache"
printf '%s\n' "$image" > "${HOME}/.cache/current-wallpaper"

if command -v matugen >/dev/null 2>&1; then
	matugen image "$image" --mode dark --prefer saturation >/dev/null 2>&1 || true
	"${HOME}/.config/hypr/scripts/quickshell-reload.sh" >/dev/null 2>&1 || true
	command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
fi
