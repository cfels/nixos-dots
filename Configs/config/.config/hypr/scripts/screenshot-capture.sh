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

if command -v notify-send >/dev/null 2>&1; then
	timeout 2 notify-send -a screenshot -i "$out" "Screenshot saved" "$(basename "$out")" || true
fi
