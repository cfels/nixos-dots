#!/usr/bin/env bash
set -euo pipefail

art="${1:-}"
track="${2:-}"
artist="${3:-}"
title="${4:-}"
dest="${5:-}"

[ -n "$dest" ] || exit 1

mkdir -p "$(dirname "$dest")"

download() {
	local url="$1"

	[ -n "$url" ] || return 1

	if curl -sfL --max-time 12 -o "$dest.part" "$url"; then
		if [ -s "$dest.part" ]; then
			mv -f "$dest.part" "$dest"
			return 0
		fi
	fi

	rm -f "$dest.part"
	return 1
}

local_image() {
	local src="$1"

	case "$src" in
		file://*) src="${src#file://}" ;;
	esac

	if [ -f "$src" ]; then
		cp -f "$src" "$dest"
		return 0
	fi

	return 1
}

case "$track" in
	*"youtube.com/watch?v="*|*"youtu.be/"*|*"music.youtube.com/watch?v="*)
		id="$(printf '%s' "$track" | sed -n 's/.*[?&]v=\([A-Za-z0-9_-]\{6,\}\).*/\1/p')"

		if [ -z "$id" ]; then
			id="$(printf '%s' "$track" | sed -n 's#.*youtu\.be/\([A-Za-z0-9_-]\{6,\}\).*#\1#p')"
		fi

		if [ -n "$id" ]; then
			download "https://img.youtube.com/vi/${id}/maxresdefault.jpg" && exit 0
			download "https://img.youtube.com/vi/${id}/hqdefault.jpg" && exit 0
		fi
		;;
esac

if [ -n "$artist" ] || [ -n "$title" ]; then
	query="$(printf '%s %s' "$artist" "$title" | sed -e 's/^ *//' -e 's/ *$//')"
	results="$(curl -sfL --max-time 10 -G --data-urlencode "term=$query" --data-urlencode "entity=song" --data-urlencode "limit=4" "https://itunes.apple.com/search" 2>/dev/null || true)"

	for candidate in $(printf '%s' "$results" | jq -r '.results[]? | .artworkUrl100 // empty' 2>/dev/null | head -4); do
		high="${candidate/100x100bb/1200x1200bb}"
		download "$high" && exit 0
	done
fi

case "$art" in
	http*) download "$art" && exit 0 ;;
	*) local_image "$art" && exit 0 ;;
esac

rm -f "$dest"
exit 1
