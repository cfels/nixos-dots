#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

dir="$1"
screenshots="$2"
shift 2
mkdir -p "$dir"

declare -A retained=()
for id in "$@"; do
	[[ "$id" =~ ^[0-9]+$ ]] || continue
	retained["$id"]=1
done

for preview in "$dir"/*.png; do
	id="${preview##*/}"
	id="${id%.png}"
	[[ "$id" =~ ^[0-9]+$ ]] || continue
	if [[ ! -v retained["$id"] ]]; then
		rm -f -- "$preview" "$dir/$id.label"
	fi
done

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

	label=""
	if [ -s "$dir/$id.label" ]; then
		read -r label < "$dir/$id.label"
	fi
	if [[ "$label" != "Image" && "$label" != "Screenshot" ]]; then
		label="Image"
		for screenshot in "$screenshots"/*.png; do
			if cmp -s "$preview" "$screenshot"; then
				label="Screenshot"
				break
			fi
		done
		printf '%s\n' "$label" > "$dir/$id.label"
	fi
	printf '%s\t%s\n' "$id" "$label"
done
