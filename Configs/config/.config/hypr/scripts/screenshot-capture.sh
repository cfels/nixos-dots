#!/usr/bin/env bash
set -euo pipefail

mode="${1:-full}"
out="${2:-}"

fail() {
	printf '%s\n' "$1" >&2
	if command -v notify-send >/dev/null 2>&1; then
		timeout 2 notify-send -u critical -a screenshot "Screenshot failed" "$1" 2>/dev/null || true
	fi
	exit 1
}

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

notify_saved() {
	if command -v notify-send >/dev/null 2>&1; then
		timeout 2 notify-send -a screenshot -i "$1" "Screenshot saved" "$(basename "$1")" || true
	fi
}

if [ "$mode" = "frozen" ]; then
	x="${2:-0}"
	y="${3:-0}"
	w="${4:-0}"
	h="${5:-0}"
	out="${6:-}"

	[ -n "$out" ] || fail "no output path was given"
	[ "$w" -gt 0 ] && [ "$h" -gt 0 ] || fail "invalid selection"

	frame="${XDG_RUNTIME_DIR:-/tmp}/moxi-freeze.png"
	[ -f "$frame" ] || fail "no frozen frame available"

	crop="$(resolve magick || resolve convert)" || fail "imagemagick is not installed"
	clip="$(resolve wl-copy)" || fail "wl-copy is not installed"

	mkdir -p "$(dirname "$out")"

	"$crop" "$frame" -crop "${w}x${h}+${x}+${y}" +repage "$out"
	"$clip" -t image/png < "$out"

	notify_saved "$out"
	exit 0
fi

[ -n "$out" ] || fail "no output path was given"

grim="$(resolve grim)" || fail "grim is not installed"
clip="$(resolve wl-copy)" || fail "wl-copy is not installed"

mkdir -p "$(dirname "$out")"

geometry=""

if [ "$mode" != "full" ]; then
	geometry="$mode"
elif command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
	geometry="$(hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused)) | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null || true)"
	[ "$geometry" = "null" ] && geometry=""
fi

if [ -n "$geometry" ]; then
	"$grim" -g "$geometry" - | tee "$out" | "$clip" -t image/png
else
	"$grim" - | tee "$out" | "$clip" -t image/png
fi

notify_saved "$out"
