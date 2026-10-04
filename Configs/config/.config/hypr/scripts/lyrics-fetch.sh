#!/usr/bin/env bash
set -euo pipefail

# lyric sources, tried in order, first synced hit wins:
#   lrclib      https://lrclib.net/api/get + /api/search                             synced + plain
#   netease     https://music.163.com/api/search/get + /api/song/lyric               synced
#   qq          https://c.y.qq.com/soso/fcgi-bin/client_search_cp
#               https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg            synced
#   kugou       https://mobilecdn.kugou.com/api/v3/search/song
#               https://krcs.kugou.com/search + https://lyrics.kugou.com/download    synced
#   lyrics.ovh  https://api.lyrics.ovh/v1/<artist>/<title>                           plain
#   apple music https://amp-api.music.apple.com/v1/catalog/<store>/songs/<id>/lyrics  needs APPLE_MUSIC_TOKEN
#
# the rest of the names that float around are clients, not lyric backends:
#   lyricify (WXRIW/Lyricify-App), betterlyrics (jayfunc/BetterLyrics),
#   unison (better-lyrics/unison, self hosted: /lyrics + /challenge + API_KEY),
#   simpmusic (maxrave-dev/SimpMusic, youtube music backend), binilyrics, lunabeat,
#   soda / luna (汽水音乐 Soda Music), youtube music (innertube "Lyrics" tab browse,
#   unauthenticated calls answer "Lyrics not available"), musixmatch (apic-desktop,
#   the anonymous token.get now returns an all zero token and the api answers with
#   garbage, so it needs a real account/usertoken), petitlyrics (official api needs a
#   registered consumer key). they all front one of the endpoints above.

artist="${1:-}"
title="${2:-}"
album="${3:-}"
length="${4:-0}"
track="${5:-}"

[ -n "$title" ] || exit 0

UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
QUERY="$(printf '%s %s' "$artist" "$title" | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//')"

duration=0
synced=""
plain=""

deadline=$(( $(date +%s) + ${LYRICS_BUDGET:-20} ))

net() {
	curl -sfL --connect-timeout 4 --max-time "${LYRICS_TIMEOUT:-7}" -A "$UA" "$@" 2>/dev/null || true
}

take() {
	local shaped d s p

	shaped="$(printf '%s' "${1:-}" | jq -c '{duration: (.duration // 0), syncedLyrics: (.syncedLyrics // ""), plainLyrics: (.plainLyrics // "")}' 2>/dev/null || true)"
	[ -n "$shaped" ] || return 0

	d="$(printf '%s' "$shaped" | jq -r '.duration // 0')"
	if [ "$duration" = "0" ] && [ "${d%.*}" -gt 0 ] 2>/dev/null; then
		duration="${d%.*}"
	fi

	s="$(printf '%s' "$shaped" | jq -r '.syncedLyrics // ""')"
	p="$(printf '%s' "$shaped" | jq -r '.plainLyrics // ""')"

	if [ -n "$s" ] && [ -z "$synced" ]; then synced="$s"; fi
	if [ -n "$p" ] && [ -z "$plain" ]; then plain="$p"; fi

	return 0
}

prov_lrclib() {
	local args=(--data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title")

	if [ "${length%.*}" -gt 0 ] 2>/dev/null; then
		args+=(--data-urlencode "album_name=$album" --data-urlencode "duration=${length%.*}")
	fi

	net -G "${args[@]}" "https://lrclib.net/api/get" |
		jq -c '{duration: (.duration // 0), syncedLyrics: (.syncedLyrics // ""), plainLyrics: (.plainLyrics // "")}' 2>/dev/null || true
}

prov_lrclib_search() {
	net -G --data-urlencode "q=$QUERY" "https://lrclib.net/api/search" |
		jq -c 'if type == "array" then (sort_by(if (.syncedLyrics // "") != "" then 0 else 1 end) | first // {}) else {} end' 2>/dev/null |
		jq -c '{duration: (.duration // 0), syncedLyrics: (.syncedLyrics // ""), plainLyrics: (.plainLyrics // "")}' 2>/dev/null || true
}

prov_netease() {
	local search id ms lyric

	search="$(net -G --data-urlencode "s=$QUERY" --data-urlencode "type=1" --data-urlencode "limit=1" "https://music.163.com/api/search/get")"
	id="$(printf '%s' "$search" | jq -r '.result.songs[0].id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0

	ms="$(printf '%s' "$search" | jq -r '.result.songs[0].duration // 0' 2>/dev/null || true)"
	lyric="$(net "https://music.163.com/api/song/lyric?id=${id}&lv=1&kv=1&tv=-1")"

	printf '%s' "$lyric" | jq -c --argjson ms "${ms:-0}" '{
		duration: (($ms / 1000) | floor),
		syncedLyrics: (.lrc.lyric // ""),
		plainLyrics: ((.lrc.lyric // "") | gsub("\\[[0-9:.]+\\]"; ""))
	}' 2>/dev/null || true
}

prov_qq() {
	local search mid secs lyric

	search="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "w=$QUERY" --data-urlencode "p=1" --data-urlencode "n=3" --data-urlencode "format=json" "https://c.y.qq.com/soso/fcgi-bin/client_search_cp")"
	mid="$(printf '%s' "$search" | jq -r '.data.song.list[0].songmid // empty' 2>/dev/null || true)"
	[ -n "$mid" ] || return 0

	secs="$(printf '%s' "$search" | jq -r '.data.song.list[0].interval // 0' 2>/dev/null || true)"
	lyric="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "songmid=$mid" --data-urlencode "format=json" --data-urlencode "nobase64=1" --data-urlencode "g_tk=5381" "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")"

	printf '%s' "$lyric" | jq -c --argjson secs "${secs:-0}" '{
		duration: ($secs // 0),
		syncedLyrics: (.lyric // ""),
		plainLyrics: ""
	}' 2>/dev/null || true
}

prov_kugou() {
	local search hash secs kr id key dl b64

	search="$(net "http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=$(printf '%s' "$QUERY" | jq -sRr @uri)&page=1&pagesize=3")"
	hash="$(printf '%s' "$search" | jq -r '.data.info[0].hash // empty' 2>/dev/null || true)"
	[ -n "$hash" ] || return 0

	secs="$(printf '%s' "$search" | jq -r '.data.info[0].duration // 0' 2>/dev/null || true)"
	kr="$(net "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=${secs:-0}&hash=$hash")"
	id="$(printf '%s' "$kr" | jq -r '.candidates[0].id // empty' 2>/dev/null || true)"
	key="$(printf '%s' "$kr" | jq -r '.candidates[0].accesskey // empty' 2>/dev/null || true)"
	[ -n "$id" ] && [ -n "$key" ] || return 0

	dl="$(net "https://lyrics.kugou.com/download?ver=1&client=pc&id=$id&accesskey=$key&fmt=lrc&charset=utf8")"
	b64="$(printf '%s' "$dl" | jq -r '.content // empty' 2>/dev/null || true)"
	[ -n "$b64" ] || return 0

	jq -cn --argjson secs "${secs:-0}" --arg lrc "$(printf '%s' "$b64" | base64 -d 2>/dev/null || true)" '{
		duration: ($secs // 0),
		syncedLyrics: $lrc,
		plainLyrics: ""
	}'
}

prov_lyricsovh() {
	local body

	body="$(net "https://api.lyrics.ovh/v1/$(printf '%s' "$artist" | jq -sRr @uri)/$(printf '%s' "$title" | jq -sRr @uri)")"

	printf '%s' "$body" | jq -c '{duration: 0, syncedLyrics: "", plainLyrics: (.lyrics // "")}' 2>/dev/null || true
}

prov_apple() {
	[ -n "${APPLE_MUSIC_TOKEN:-}" ] || return 0

	local store="${APPLE_MUSIC_STOREFRONT:-us}" id body

	id="$(net -H "Authorization: Bearer $APPLE_MUSIC_TOKEN" -H 'Origin: https://music.apple.com' \
		-G --data-urlencode "term=$QUERY" --data-urlencode "types=songs" --data-urlencode "limit=1" \
		"https://amp-api.music.apple.com/v1/catalog/$store/search" |
		jq -r '.results.songs.data[0].id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0

	body="$(net -H "Authorization: Bearer $APPLE_MUSIC_TOKEN" -H 'Origin: https://music.apple.com' \
		"https://amp-api.music.apple.com/v1/catalog/$store/songs/$id/lyrics?l%5Blyrics%5D=lyrics&extend=ttmlLocalizations")"

	printf '%s' "$body" | jq -c '{duration: 0, syncedLyrics: "", plainLyrics: (.data[0].attributes.lyrics // "")}' 2>/dev/null || true
}

if [ -n "$track" ]; then
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

if [ -z "$synced" ]; then
	for p in lrclib lrclib_search netease qq kugou; do
		take "$("prov_$p")"

		[ -n "$synced" ] && break
		[ "$(date +%s)" -gt "$deadline" ] && break
	done
fi

if [ -z "$synced" ]; then
	take "$(prov_lyricsovh)"
	[ -n "$synced" ] || take "$(prov_apple)"
fi

if [ "$duration" = "0" ]; then
	iTunes_ms="$(net -G --data-urlencode "term=$QUERY" --data-urlencode "entity=song" --data-urlencode "limit=1" "https://itunes.apple.com/search" | jq -r '.results[0].trackTimeMillis // 0' 2>/dev/null || echo 0)"

	if [ "${iTunes_ms%.*}" -gt 0 ] 2>/dev/null; then
		duration="$(awk -v ms="$iTunes_ms" 'BEGIN { printf "%d", ms / 1000 }')"
	else
		deezer_secs="$(net -G --data-urlencode "q=$QUERY" --data-urlencode "limit=1" "https://api.deezer.com/search" | jq -r '.data[0].duration // 0' 2>/dev/null || echo 0)"

		if [ "${deezer_secs%.*}" -gt 0 ] 2>/dev/null; then
			duration="${deezer_secs%.*}"
		fi
	fi
fi

jq -cn --argjson d "${duration:-0}" --arg s "$synced" --arg p "$plain" \
	'{duration: $d, syncedLyrics: $s, plainLyrics: $p}'
