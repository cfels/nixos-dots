#!/usr/bin/env bash
set -euo pipefail

art="${1:-}"
track="${2:-}"
artist="${3:-}"
title="${4:-}"
dest="${5:-}"
current="${6:-}"
album="${7:-}"
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"

# Ensure the destination directory exists
[ -n "$dest" ] || exit 1

# Create directory if needed, removing any existing file with same name
mkdir -p "$(dirname "$dest")"
rm -f "$dest"

partial="$(mktemp "$dest.part.XXXXXX")"
best="$(mktemp "$dest.best.XXXXXX")"
best_size=0
trap 'rm -f -- "$partial" "$best"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

valid_image() {
	[ -s "$1" ] && [ "$(stat -c %s -- "$1")" -le 16777216 ] &&
		magick -regard-warnings -limit memory 64MiB -limit map 128MiB -limit disk 0 \
			-limit width 8192 -limit height 8192 -limit time 5 "$1[0]" null: >/dev/null 2>&1
}

resolution() {
	magick identify -quiet -format '%[fx:min(w,h)]' "$1[0]" 2>/dev/null
}

publish() {
	local duplicate=""
	[ -s "$best" ] || return 1
	if same_as_shown "$best"; then duplicate=1; fi
	mv -f -- "$best" "$dest" || return 1
	purge
	[ -z "$duplicate" ] || exit 2
}

consider() {
	local size
	valid_image "$partial" || return 1
	size="$(resolution "$partial")" || return 1
	if [ "$size" -gt "$best_size" ]; then
		cp -f -- "$partial" "$best" || return 1
		best_size="$size"
	fi
	[ "$best_size" -ge 512 ] || return 1
	publish
}

same_as_shown() {
	[ -n "$current" ] && [ -f "$current" ] && [ -f "$1" ] && cmp -s "$1" "$current"
}

purge() {
	python3 "$SCRIPT_DIR/media-cache.py" prune || true
}

download() {
	local url="$1"

	case "$url" in
		http://*|https://*) ;;
		*) return 1 ;;
	esac

	if curl -sfL --proto '=http,https' --proto-redir '=http,https' --connect-timeout 2 \
		--max-time 12 --max-filesize 16777216 -o "$partial" "$url"; then
		consider && return 0
	fi

	return 1
}

local_image() {
	local src="$1"

	case "$src" in
		file://*)
			src="$(python3 -c 'import sys, urllib.parse as u; p=u.urlsplit(sys.argv[1]); sys.exit(1) if p.netloc not in ("", "localhost") else None; print(u.unquote(p.path, errors="strict"))' "$src")" || return 1
			;;
	esac

	if [ -f "$src" ] && cp -f -- "$src" "$partial"; then
		consider && return 0
	fi

	return 1
}

# Check if we already have a valid cached image
if [ -f "$dest" ]; then
	if valid_image "$dest"; then
		best_size="$(resolution "$dest")"
		if [ "$best_size" -ge 512 ]; then
			touch -- "$dest"
			purge
			same_as_shown "$dest" && exit 2
			exit 0
		fi
		cp -f -- "$dest" "$best"
	else
		rm -f -- "$dest"
	fi
fi

# Try to get artwork from various sources in order of preference
case "$art" in
	http://*|https://*) download "$art" && exit 0 ;;
	*) local_image "$art" && exit 0 ;;
esac

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

if [ -n "$artist" ] && [ -n "$title" ]; then
	query_artist="$(printf '%s' "$artist" | jq -L "$SCRIPT_DIR" -sRr 'include "media-match"; artists | join(" ")')"
	query="$query_artist $title"
	results="$(curl -sfL --proto '=https' --proto-redir '=https' --connect-timeout 2 --max-time 10 \
		-G --data-urlencode "term=$query" --data-urlencode "entity=song" --data-urlencode "limit=4" \
		"https://itunes.apple.com/search" 2>/dev/null || true)"

	while IFS= read -r candidate; do
		[ -n "$candidate" ] || continue
		high="${candidate/100x100bb/1200x1200bb}"
		download "$high" && exit 0
	done < <(printf '%s' "$results" | jq -L "$SCRIPT_DIR" -r --arg title "$title" --arg artist "$artist" --arg album "$album" '
		include "media-match";
		[(.results // [])[] | {title: .trackName, artist: .artistName, album: .collectionName, artwork: .artworkUrl100}]
		| matched_tracks($title; $artist; $album; 0) | .[].artwork // empty' 2>/dev/null)
fi

# If we have a valid best image, publish it
[ "$best_size" -le 0 ] || { publish && exit 0; }
exit 1
