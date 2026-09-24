#!/usr/bin/env bash
set -euo pipefail

mode="${1:-classic}"
shift || true

[ "$#" -gt 0 ] || exit 1

command -v hyprctl >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1

clients="$(hyprctl clients -j 2>/dev/null)" || exit 1
[ -n "$clients" ] || exit 1

lower() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

match=""

for pass in exact contains; do
	[ -n "$match" ] && break

	for candidate in "$@"; do
		needle="$(lower "$candidate")"
		[ -n "$needle" ] || continue

		if [ "$pass" = "exact" ]; then
			match="$(printf '%s' "$clients" | jq -r --arg q "$needle" \
				'[.[] | select(((.class | ascii_downcase) == $q) or (((.initialClass // "") | ascii_downcase) == $q))] | first | .address // empty' 2>/dev/null || true)"
		else
			match="$(printf '%s' "$clients" | jq -r --arg q "$needle" \
				'[.[] | select((((.class | ascii_downcase) | contains($q))) or ((((.initialClass // "") | ascii_downcase) | contains($q))) or (((.title | ascii_downcase) | contains($q))))] | first | .address // empty' 2>/dev/null || true)"
		fi

		[ -n "$match" ] && break
	done
done

[ -n "$match" ] || exit 1

selector="address:$match"

if [ "$mode" = "lua" ]; then
	hyprctl dispatch "hl.dsp.focus({ window = \"$selector\" })" >/dev/null 2>&1
else
	hyprctl dispatch "focuswindow $selector" >/dev/null 2>&1
fi
