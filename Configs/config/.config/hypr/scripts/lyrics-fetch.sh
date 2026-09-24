#!/usr/bin/env bash
set -euo pipefail

artist="${1:-}"
title="${2:-}"
album="${3:-}"
length="${4:-0}"
track="${5:-}"

[ -n "$title" ] || exit 0

duration=0
lyrics=""
synced=""

shape() {
	jq -c '{duration: (.duration // 0), syncedLyrics: (.syncedLyrics // ""), plainLyrics: (.plainLyrics // "")}' 2>/dev/null || true
}

lrclib_get() {
	local with_duration="$1"

	if [ "$with_duration" = "yes" ] && [ "${length%.*}" -gt 0 ] 2>/dev/null; then
		curl -sfL --max-time 8 -G \
			--data-urlencode "artist_name=$artist" \
			--data-urlencode "track_name=$title" \
			--data-urlencode "album_name=$album" \
			--data-urlencode "duration=${length%.*}" \
			"https://lrclib.net/api/get" 2>/dev/null || true
	else
		curl -sfL --max-time 8 -G \
			--data-urlencode "artist_name=$artist" \
			--data-urlencode "track_name=$title" \
			"https://lrclib.net/api/get" 2>/dev/null || true
	fi
}

take() {
	local payload="$1"
	local shaped
	shaped="$(printf '%s' "$payload" | shape)"

	[ -n "$shaped" ] || return 0

	local d
	d="$(printf '%s' "$shaped" | jq -r '.duration // 0')"
	[ "${d%.*}" -gt "$duration" ] 2>/dev/null && duration="${d%.*}"

	local s p
	s="$(printf '%s' "$shaped" | jq -r '.syncedLyrics // ""')"
	p="$(printf '%s' "$shaped" | jq -r '.plainLyrics // ""')"

	if [ -z "$synced" ] && [ -n "$s" ]; then
		synced="$s"
	elif [ -z "$lyrics" ] && [ -n "$p" ]; then
		lyrics="$p"
	fi
}

take "$(lrclib_get yes)"
take "$(lrclib_get no)"

if [ "$duration" = "0" ] || { [ -z "$synced" ] && [ -z "$lyrics" ]; }; then
	query="$(printf '%s %s' "$artist" "$title" | sed -e 's/^ *//' -e 's/ *$//')"
	found="$(curl -sfL --max-time 8 -G --data-urlencode "q=$query" "https://lrclib.net/api/search" 2>/dev/null | jq -c 'sort_by(if (.syncedLyrics // "") != "" then 0 else 1 end) | first // empty' 2>/dev/null || true)"
	take "$found"
fi

if [ "$duration" = "0" ] || { [ -z "$synced" ] && [ -z "$lyrics" ]; }; then
	query="$(printf '%s %s' "$artist" "$title" | sed -e 's/^ *//' -e 's/ *$//')"
	search_json="$(curl -sfL --max-time 8 -A 'Mozilla/5.0' -G --data-urlencode "s=$query" --data-urlencode "type=1" --data-urlencode "limit=1" "https://music.163.com/api/search/get" 2>/dev/null || true)"
	song_id="$(printf '%s' "$search_json" | jq -r '.result.songs[0].id // empty' 2>/dev/null || true)"
	song_ms="$(printf '%s' "$search_json" | jq -r '.result.songs[0].duration // 0' 2>/dev/null || echo 0)"

	if [ "${song_ms%.*}" -gt 0 ] 2>/dev/null && [ "$duration" = "0" ]; then
		duration="$(awk -v ms="$song_ms" 'BEGIN { printf "%d", ms / 1000 }')"
	fi

	if [ -n "$song_id" ] && [ -z "$synced" ] && [ -z "$lyrics" ]; then
		lyric_json="$(curl -sfL --max-time 8 -A 'Mozilla/5.0' "https://music.163.com/api/song/lyric?id=${song_id}&lv=1&kv=1&tv=-1" 2>/dev/null || true)"
		synced="$(printf '%s' "$lyric_json" | jq -r '.lrc.lyric // empty' 2>/dev/null || true)"
		lyrics="$(printf '%s' "$lyric_json" | jq -r '."tlyric".lyric // empty' 2>/dev/null || true)"
	fi
fi

if [ -z "$synced" ] && [ -z "$lyrics" ]; then
	encoded_artist="$(printf '%s' "$artist" | jq -sRr @uri)"
	encoded_title="$(printf '%s' "$title" | jq -sRr @uri)"
	lyrics="$(curl -sfL --max-time 8 "https://api.lyrics.ovh/v1/${encoded_artist}/${encoded_title}" 2>/dev/null | jq -r '.lyrics // empty' 2>/dev/null || true)"
fi

if [ -z "$synced" ] && [ -z "$lyrics" ] && [ -n "$track" ]; then
	case "$track" in
		file://*)
			local_lrc="${track#file://}"
			local_lrc="${local_lrc%.*}.lrc"

			if [ -f "$local_lrc" ]; then
				synced="$(cat "$local_lrc")"
			fi
			;;
	esac
fi

jq -cn --argjson d "${duration:-0}" --arg s "$synced" --arg p "$lyrics" \
	'{duration: $d, syncedLyrics: $s, plainLyrics: $p}'
