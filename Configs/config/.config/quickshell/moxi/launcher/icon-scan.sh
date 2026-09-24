#!/usr/bin/env bash
set -u

theme="$(sed -n 's/^Theme=//p' "$HOME/.config/kdeglobals" 2>/dev/null | head -n 1)"
[ -n "$theme" ] || theme="breeze-dark"

IFS=':' read -r -a bases <<< "$HOME/.local/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

rank=0
seen=""

for name in "$theme" breeze-dark breeze hicolor; do
	case " $seen " in
		*" $name "*) continue ;;
	esac

	seen="$seen $name"

	for base in "${bases[@]}"; do
		[ -d "$base/icons/$name" ] || continue

		find -L "$base/icons/$name" -maxdepth 3 -type f \( -name '*.svg' -o -name '*.png' \) -printf "$rank\t%p\n"
	done

	rank=$((rank + 1))
done | awk -F'\t' '
{
	rank = $1
	path = $2
	name = path
	sub(/.*\//, "", name)
	sub(/\.[^.]*$/, "", name)

	dir = path
	sub(/\/[^\/]*$/, "", dir)
	last = dir
	sub(/.*\//, "", last)
	parent = dir
	sub(/\/[^\/]*$/, "", parent)
	sub(/.*\//, "", parent)

	score = 0

	if (path ~ /scalable/ || path ~ /\.svg$/) {
		score = 1000
	} else {
		if (match(last, /[0-9]+/)) score = substr(last, RSTART, RLENGTH) + 0
		if (match(parent, /[0-9]+/)) {
			value = substr(parent, RSTART, RLENGTH) + 0
			if (value > score) score = value
		}
	}

	key = rank * 100000 - score

	if (!(name in best) || key < best[name]) {
		best[name] = key
		file[name] = path
	}
}
END {
	for (entry in file) print entry "\t" file[entry]
}'
