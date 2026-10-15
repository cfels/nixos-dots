#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

dir="$1"
screenshots="$2"
shift 2
mkdir -p "$dir"

for id in "$@"; do
	[[ "$id" =~ ^[0-9]+$ ]] || continue
	preview="$dir/$id.png"
	if [ ! -s "$preview" ]; then
		if ! cliphist decode "$id" > "$preview"; then
			rm -f "$preview"
			continue
		fi
	fi
	[ -s "$preview" ] || continue

	label="Image"
	for screenshot in "$screenshots"/*.png; do
		if cmp -s "$preview" "$screenshot"; then
			label="Screenshot"
			break
		fi
	done
	printf '%s\t%s\n' "$id" "$label"
done
