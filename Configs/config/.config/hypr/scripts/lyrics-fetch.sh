#!/usr/bin/env bash
set -euo pipefail

#   lrclib      https://lrclib.net/api/get + /api/search                             synced + plain
#   netease     https://music.163.com/api/search/get + /api/song/lyric               synced
#   qq          https://c.y.qq.com/soso/fcgi-bin/client_search_cp
#               https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg            synced
#   kugou       https://mobilecdn.kugou.com/api/v3/search/song
#               https://krcs.kugou.com/search + https://lyrics.kugou.com/download    synced
#   apple music https://amp-api.music.apple.com/v1/catalog/<store>/songs/<id>/lyrics  needs APPLE_MUSIC_TOKEN
#
#   lyricsplus  /v2/lyrics/get on the public mirrors used by YouLy+ and ArchiveTune
#               Apple Music, Musixmatch, Spotify, QQ, and community submissions
#   unison      https://unison.boidu.dev/lyrics/search + /lyrics                   LRC + TTML
#   betterlyrics https://lyrics-api.boidu.dev/getLyrics (+ kugou/ and qq/)         TTML + QRC
#   simpmusic   https://api-lyrics.simpmusic.org/v1/<video-id>                     synced + plain
#   paxsenix    https://api.paxsenix.org/lyrics/*                                  needs PAXSENIX_API_KEY
#               lrcget, Musixmatch, Apple Music, and Spotify
#
# Provider API/format references:
#   https://github.com/rukamori/lyrics
#   https://github.com/ibratabian17/lyricsplus/blob/cookie/docs/endpoints.md
# TTML, word-timed JSON, enhanced LRC, and QRC are converted to the panel's LRC.

artist="${1:-}"
title="${2:-}"
album="${3:-}"
length="${4:-0}"
track="${5:-}"

[ -n "$title" ] || exit 0

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
QUERY="$(printf '%s %s' "$artist" "$title" | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//')"
WANT_SECS="$(printf '%s' "${length%%.*}" | sed -e 's/[^0-9]//g')"
[ -n "$WANT_SECS" ] || WANT_SECS=0

JQ_MATCH='
def norm: ascii_downcase | gsub("[^\\p{L}\\p{N}]+"; " ") | gsub("^ +| +$"; "");
def artists: ascii_downcase | [splits("\\s+(?:feat\\.?|ft\\.?|featuring)\\s+|\\s*[,;&]\\s*")] | map(norm) | map(select(length > 0));
def adiff: if . < 0 then -. else . end;
($title | norm) as $wantT
| ($artist | artists) as $wantA
| ($album | norm) as $wantAlbum
| (($dur // 0) | if . < 0 then 0 else . end) as $wantD
| [ .[]
	| . as $c
	| (($c.title // "") | norm) as $ct
	| (($c.artist // "") | artists) as $ca
	| select($wantT != "" and $ct == $wantT)
	| select(($wantA | length) > 0 and ($wantA - $ca | length) == 0)
	| select($wantD <= 0 or ($c.duration // 0) <= 0 or (((($c.duration // 0) - $wantD) | adiff) <= 3))
	| $c + {
		score: ((if $ca == $wantA then 2 else 1 end)
			+ (if $wantAlbum != "" and (($c.album // "") | norm) == $wantAlbum then 2 else 0 end)
			+ (if ($wantD > 0 and ($c.duration // 0) > 0)
				then ((($c.duration // 0) - $wantD) | adiff) as $dd
					| 4 - $dd
				else 0 end))
	}
]
| sort_by(-.score, if ((.synced // .syncedLyrics // "") | length) > 0 then 0 else 1 end)
| .[0] // {}
'

pick() {
	jq -c --arg title "$title" --arg artist "$artist" --arg album "$album" --argjson dur "$WANT_SECS" "$JQ_MATCH" 2>/dev/null || printf '{}'
}

match_payload() {
	jq -c --argjson dur "$WANT_SECS" '[.
		| select((.syncedLyrics // "") != "" or (.plainLyrics // "") != "")
		| if $dur > 0 and (.duration // 0) <= 0 then .syncedLyrics = "" else . end
	]' | pick
}

with_metadata() {
	jq -c --argjson metadata "$1" '. + ($metadata | {title, artist, album, duration})'
}

duration="$WANT_SECS"
synced=""
plain=""
length_done=""
lyric_pids=""
length_pid=""

net() {
	curl -sfL --connect-timeout 2 --max-time "${LYRICS_TIMEOUT:-4}" -A "$UA" "$@" 2>/dev/null || true
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
		jq -c '. + {title: (.trackName // ""), artist: (.artistName // ""), album: (.albumName // "")}' 2>/dev/null || true
}

prov_lrclib_search() {
	net -G --data-urlencode "q=$QUERY" "https://lrclib.net/api/search" |
		jq -c 'if type == "array" then [ .[] | {title: (.trackName // ""), artist: (.artistName // ""), album: (.albumName // ""), duration: (.duration // 0), synced: (.syncedLyrics // ""), plain: (.plainLyrics // "")} | select(.synced != "" or .plain != "")] else [] end' 2>/dev/null |
		pick |
		jq -c '. + {syncedLyrics: (.synced // ""), plainLyrics: (.plain // "")}' 2>/dev/null || true
}

prov_netease() {
	local search picked id ms lyric

	search="$(net -G --data-urlencode "s=$QUERY" --data-urlencode "type=1" --data-urlencode "limit=8" "https://music.163.com/api/search/get")"
	search="$(printf '%s' "$search" | jq -c '[(.result.songs // [])[] | {id: .id, title: (.name // ""), artist: ([.artists[]?.name] | join(" & ")), album: (.album.name // ""), duration: ((.duration // 0) / 1000)}]' 2>/dev/null || printf '[]')"

	picked="$(printf '%s' "$search" | pick)"
	id="$(printf '%s' "$picked" | jq -r '.id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0

	ms="$(printf '%s' "$picked" | jq -r '((.duration // 0) * 1000) | floor' 2>/dev/null || true)"
	lyric="$(net "https://music.163.com/api/song/lyric?id=${id}&lv=1&kv=1&tv=-1")"

	printf '%s' "$lyric" | jq -c --argjson ms "${ms:-0}" '{
		duration: (($ms / 1000) | floor),
		syncedLyrics: (.lrc.lyric // ""),
		plainLyrics: ((.lrc.lyric // "") | gsub("\\[[0-9:.]+\\]"; ""))
	}' 2>/dev/null | with_metadata "$picked" || true
}

prov_qq() {
	local search picked mid secs lyric

	search="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "w=$QUERY" --data-urlencode "p=1" --data-urlencode "n=8" --data-urlencode "format=json" "https://c.y.qq.com/soso/fcgi-bin/client_search_cp")"
	search="$(printf '%s' "$search" | jq -c '[(.data.song.list // [])[] | {mid: .songmid, title: (.songname // ""), artist: ([.singer[]?.name] | join(" & ")), album: (.albumname // ""), duration: (.interval // 0)}]' 2>/dev/null || printf '[]')"

	picked="$(printf '%s' "$search" | pick)"
	mid="$(printf '%s' "$picked" | jq -r '.mid // empty' 2>/dev/null || true)"
	[ -n "$mid" ] || return 0

	secs="$(printf '%s' "$picked" | jq -r '.duration // 0' 2>/dev/null || true)"
	lyric="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "songmid=$mid" --data-urlencode "format=json" --data-urlencode "nobase64=1" --data-urlencode "g_tk=5381" "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")"

	printf '%s' "$lyric" | jq -c --argjson secs "${secs:-0}" '{
		duration: ($secs // 0),
		syncedLyrics: (.lyric // ""),
		plainLyrics: ""
	}' 2>/dev/null | with_metadata "$picked" || true
}

prov_kugou() {
	local search picked hash secs kr id key dl b64

	search="$(net "http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=$(printf '%s' "$QUERY" | jq -sRr @uri)&page=1&pagesize=8")"
	search="$(printf '%s' "$search" | jq -c '[(.data.info // [])[] | {hash: .hash, title: (.songname // ""), artist: (.singername // ""), duration: (.duration // 0)}]' 2>/dev/null || printf '[]')"

	picked="$(printf '%s' "$search" | pick)"
	hash="$(printf '%s' "$picked" | jq -r '.hash // empty' 2>/dev/null || true)"
	[ -n "$hash" ] || return 0

	secs="$(printf '%s' "$picked" | jq -r '.duration // 0' 2>/dev/null || true)"
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
	}' | with_metadata "$picked"
}

normalize() {
	python3 "$SCRIPT_DIR/lyrics-normalize.py" "$WANT_SECS"
}

has_lyrics() {
	jq -e '((.syncedLyrics // "") | length) > 0 or ((.plainLyrics // "") | length) > 0' >/dev/null 2>&1
}

video_id() {
	case "${track:-}" in
		*youtube.com/*|*youtu.be/*) ;;
		*) return 0 ;;
	esac
	printf '%s' "$track" | sed -n \
		-e 's/.*[?&]v=\([A-Za-z0-9_-]\{11\}\).*/\1/p' \
		-e 's#.*youtu\.be/\([A-Za-z0-9_-]\{11\}\).*#\1#p' \
		-e 's#.*youtube\.com/\(shorts\|embed\)/\([A-Za-z0-9_-]\{11\}\).*#\2#p' | head -1
}

metadata_request() {
	local url="$1" title_key="${2:-title}" artist_key="${3:-artist}"
	local album_key="${4:-album}" duration_key="${5:-duration}"
	local args=(--data-urlencode "$title_key=$title" --data-urlencode "$artist_key=$artist")
	[ -z "$album" ] || args+=(--data-urlencode "$album_key=$album")
	[ "$WANT_SECS" -le 0 ] || args+=(--data-urlencode "$duration_key=$WANT_SECS")
	net -H 'Accept: application/json' -H 'X-Client-Package: Moxi Quickshell' -G "${args[@]}" "$url"
}

prov_lyricsplus() {
	metadata_request "${LYRICSPLUS_URL:-https://lyricsplus.binimum.org}/v2/lyrics/get" | normalize
}

prov_lyricsplus_backup() {
	metadata_request "https://lyricsplus.prjktla.my.id/v2/lyrics/get" | normalize
}

prov_betterlyrics() {
	metadata_request "https://lyrics-api.boidu.dev/getLyrics" s a al d | normalize
}

prov_betterlyrics_kugou() {
	metadata_request "https://lyrics-api.boidu.dev/kugou/getLyrics" s a al d | normalize
}

prov_betterlyrics_qq() {
	metadata_request "https://lyrics-api.boidu.dev/qq/getLyrics" s a al d | normalize
}

prov_unison() {
	local picked id body decoded

	picked="$(metadata_request "https://unison.boidu.dev/lyrics/search" song artist |
		jq -c 'if .success == true then [(.data // [])[] | {id: .id, title: (.song // ""), artist: (.artist // ""), synced: (.lyrics // ""), payload: .}] else [] end' 2>/dev/null |
		pick)"
	body="$(printf '%s' "$picked" | jq -c '.payload // {}' 2>/dev/null || true)"
	decoded="$(printf '%s' "$body" | normalize)"
	if printf '%s' "$decoded" | has_lyrics; then
		printf '%s\n' "$decoded" | with_metadata "$picked"
		return 0
	fi
	id="$(printf '%s' "$picked" | jq -r '.id // empty' 2>/dev/null || true)"
	if [[ "$id" =~ ^[0-9]+$ ]]; then
		net "https://unison.boidu.dev/lyrics/$id" | normalize | with_metadata "$picked"
	else
		id="$(video_id)"
		[ -n "$id" ] || return 0
		net -G --data-urlencode "videoId=$id" "https://unison.boidu.dev/lyrics" | normalize
	fi
}

prov_simpmusic() {
	local id
	id="$(video_id)"
	[ -n "$id" ] || return 0

	net "https://api-lyrics.simpmusic.org/v1/$id" |
		jq -c 'if .type == "success" then [(.data // [])[] | {title: (.songTitle // ""), artist: (.artistName // ""), duration: (.durationSeconds // 0), synced: (.syncedLyrics // ""), plain: (.plainLyric // "")}] else [] end' 2>/dev/null |
		pick |
		jq -c '. + {syncedLyrics: (.synced // ""), plainLyrics: (.plain // "")}' 2>/dev/null |
		normalize
}

paxsenix_request() {
	net -H "Authorization: Bearer $PAXSENIX_API_KEY" "$@"
}

prov_paxsenix() {
	[ -n "${PAXSENIX_API_KEY:-}" ] || return 0
	paxsenix_request -G --data-urlencode "q=$QUERY" "https://api.paxsenix.org/lyrics/lrcget" | normalize
}

prov_paxsenix_musixmatch() {
	[ -n "${PAXSENIX_API_KEY:-}" ] || return 0
	paxsenix_request -G --data-urlencode "t=$title" --data-urlencode "a=$artist" \
		--data-urlencode "d=$WANT_SECS" "https://api.paxsenix.org/lyrics/musixmatch" | normalize
}

paxsenix_catalog() {
	[ -n "${PAXSENIX_API_KEY:-}" ] || return 0
	local catalog="$1" provider="$2" picked id
	picked="$(paxsenix_request -G --data-urlencode "q=$QUERY" "https://api.paxsenix.org/$catalog/search" |
		jq -c '[.. | objects | . as $track | (.attributes // .) as $details | select(($details.name // $details.title // $details.trackName) != null) | {id: ($track.id // $details.id), title: ($details.name // $details.title // $details.trackName // ""), artist: ($details.artistName // (if ($details.artists | type) == "array" then [$details.artists[]?.name] | join(" & ") else "" end)), duration: (if $details.durationInMillis then $details.durationInMillis / 1000 elif $details.duration_ms then $details.duration_ms / 1000 else ($details.duration // 0) end)}]' 2>/dev/null |
		pick)"
	id="$(printf '%s' "$picked" | jq -r '.id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0
	paxsenix_request -G --data-urlencode "id=$id" "https://api.paxsenix.org/lyrics/$provider" | normalize | with_metadata "$picked"
}

prov_paxsenix_apple() {
	paxsenix_catalog apple-music applemusic
}

prov_paxsenix_spotify() {
	paxsenix_catalog spotify spotify
}

prov_ytlength() {
	case "${track:-}" in
		*youtube.com/*|*youtu.be/*) ;;
		*) return 0 ;;
	esac

	local id body

	id="$(printf '%s' "$track" | sed -n -e 's/.*[?&]v=\([A-Za-z0-9_-]\{6,\}\).*/\1/p' -e 's#.*youtu\.be/\([A-Za-z0-9_-]\{6,\}\).*#\1#p' | head -1)"
	[ -n "$id" ] || return 0

	body="$(net -X POST -H 'Content-Type: application/json' \
		--data "$(jq -cn --arg id "$id" '{context: {client: {clientName: "WEB", clientVersion: "2.20240401.00.00", hl: "en"}}, videoId: $id, contentCheckOk: true, racyCheckOk: true}')" \
		"https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8")"

	printf '%s' "$body" | jq -r '(.microformat.playerMicroformatRenderer.lengthSeconds // .videoDetails.lengthSeconds // empty) | tostring' 2>/dev/null | head -1
}

prov_duration() {
	local secs

	secs="$(prov_ytlength)"

	if [ -n "$secs" ]; then
		printf '%s\n' "$secs"

		return 0
	fi

	prov_length
}

prov_length() {
	local work iTunes_pid deezer_pid iTunes_secs deezer_secs

	work="$(mktemp -d)"

	(
		net -G --data-urlencode "term=$QUERY" --data-urlencode "entity=song" --data-urlencode "limit=8" "https://itunes.apple.com/search" |
			jq -c '[(.results // [])[] | {title: (.trackName // ""), artist: (.artistName // ""), duration: (((.trackTimeMillis // 0) / 1000) | floor)}]' 2>/dev/null |
			pick |
			jq -r '.duration // empty' 2>/dev/null || true
	) > "$work/iTunes" &
	iTunes_pid=$!

	(
		net -G --data-urlencode "q=$QUERY" --data-urlencode "limit=8" "https://api.deezer.com/search" |
			jq -c '[(.data // [])[] | {title: (.title // ""), artist: (.artist.name // ""), duration: (.duration // 0)}]' 2>/dev/null |
			pick |
			jq -r '.duration // empty' 2>/dev/null || true
	) > "$work/deezer" &
	deezer_pid=$!

	wait "$iTunes_pid" 2>/dev/null || true
	wait "$deezer_pid" 2>/dev/null || true

	iTunes_secs="$(cat "$work/iTunes" 2>/dev/null || true)"
	deezer_secs="$(cat "$work/deezer" 2>/dev/null || true)"

	rm -rf "$work"

	if [ "${iTunes_secs:-0}" -gt 0 ] 2>/dev/null; then
		printf '%s\n' "${iTunes_secs%.*}"
	elif [ "${deezer_secs:-0}" -gt 0 ] 2>/dev/null; then
		printf '%s\n' "${deezer_secs%.*}"
	fi

	return 0
}

prov_apple() {
	[ -n "${APPLE_MUSIC_TOKEN:-}" ] || return 0

	local store="${APPLE_MUSIC_STOREFRONT:-us}" picked id body

	picked="$(net -H "Authorization: Bearer $APPLE_MUSIC_TOKEN" -H 'Origin: https://music.apple.com' \
		-G --data-urlencode "term=$QUERY" --data-urlencode "types=songs" --data-urlencode "limit=8" \
		"https://amp-api.music.apple.com/v1/catalog/$store/search" |
		jq -c '[(.results.songs.data // [])[] | {id: .id, title: (.attributes.name // ""), artist: (.attributes.artistName // ""), duration: (((.attributes.durationInMillis // 0) / 1000) | floor)}]' 2>/dev/null |
		pick)"
	id="$(printf '%s' "$picked" | jq -r '.id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0

	body="$(net -H "Authorization: Bearer $APPLE_MUSIC_TOKEN" -H 'Origin: https://music.apple.com' \
		"https://amp-api.music.apple.com/v1/catalog/$store/songs/$id/lyrics?l%5Blyrics%5D=lyrics&extend=ttmlLocalizations")"

	printf '%s' "$body" | jq -c '{duration: 0, syncedLyrics: (.data[0].attributes.ttml // ""), plainLyrics: (.data[0].attributes.lyrics // "")}' 2>/dev/null | with_metadata "$picked" || true
}

if [ "${WANT_SECS:-0}" -le 0 ] 2>/dev/null; then
	case "${track:-}" in
		*youtube.com/*|*youtu.be/*)
			yt_secs="$(prov_ytlength)"
			[ -n "$yt_secs" ] && duration="${yt_secs%.*}"
			;;
	esac
fi

if [ "$WANT_SECS" -le 0 ] && [ "${duration:-0}" -gt 0 ] 2>/dev/null; then
	WANT_SECS="$duration"
fi

if [ -n "$track" ]; then
	case "$track" in
		file://*)
			local_lrc="${track#file://}"
			local_lrc="${local_lrc%.*}.lrc"

			if [ -f "$local_lrc" ]; then
				take "$(normalize < "$local_lrc")"
			fi
			;;
	esac
fi

if [ -z "$synced" ]; then
	work="$(mktemp -d)"
	trap 'rm -rf "$work"' EXIT

	providers=(lrclib lrclib_search netease qq kugou lyricsplus lyricsplus_backup unison betterlyrics betterlyrics_kugou betterlyrics_qq simpmusic)
	if [ -n "${APPLE_MUSIC_TOKEN:-}" ]; then
		providers+=(apple)
	fi
	if [ -n "${PAXSENIX_API_KEY:-}" ]; then
		providers+=(paxsenix paxsenix_musixmatch paxsenix_apple paxsenix_spotify)
	fi

	for p in "${providers[@]}"; do
		(
			"prov_$p" | normalize | match_payload > "$work/$p.tmp" 2>/dev/null || true
			# Publish complete JSON only; never select a half-written response.
			mv "$work/$p.tmp" "$work/$p"
		) &
		lyric_pids="$lyric_pids $!"
	done

	length_pid=""

	if [ "${WANT_SECS:-0}" -le 0 ] 2>/dev/null && [ "${duration:-0}" = "0" ]; then
		( prov_duration > "$work/length" 2>/dev/null || true ) &
		length_pid=$!
		length_done=1
	fi

	stop=$(( $(date +%s) + ${LYRICS_BUDGET:-5} ))

	while :; do
		alive=""

		for pid in $lyric_pids; do
			if kill -0 "$pid" 2>/dev/null; then alive="$alive $pid"; fi
		done

		[ -n "$alive" ] || break
		[ "$(date +%s)" -lt "$stop" ] || { kill $alive 2>/dev/null || true; break; }
		sleep 0.15
	done

	wait $lyric_pids 2>/dev/null || true

	if [ -s "$work/length" ]; then
		duration="$(cat "$work/length" 2>/dev/null || true)"
		if [ "${duration:-0}" -gt 0 ] 2>/dev/null; then WANT_SECS="$duration"; fi
	fi

	candidates=()
	for p in "${providers[@]}"; do
		[ ! -s "$work/$p" ] || candidates+=("$work/$p")
	done
	if [ "${#candidates[@]}" -gt 0 ]; then
		take "$(jq -s '.' "${candidates[@]}" | pick | normalize | match_payload)"
	fi
fi

if [ "$duration" = "0" ] && [ "${WANT_SECS:-0}" -le 0 ] 2>/dev/null && [ -z "$length_done" ]; then
	duration="$(prov_duration | head -1 || true)"
fi

if [ "$duration" = "0" ] && [ "${WANT_SECS:-0}" -gt 0 ] 2>/dev/null; then
	duration="$WANT_SECS"
fi

CREDITS='(作词|作詞|作曲|编曲|編曲|produced by|written by|lyrics by)[[:space:]]*[:：]'
[ -n "$synced" ] && synced="$(printf '%s\n' "$synced" | grep -vE "$CREDITS" || true)"
[ -n "$plain" ] && plain="$(printf '%s\n' "$plain" | grep -vE "$CREDITS" || true)"

jq -cn --argjson d "${duration:-0}" --arg s "$synced" --arg p "$plain" \
	'{duration: $d, syncedLyrics: $s, plainLyrics: $p}'

if [ -n "$length_pid" ] && [ "${duration:-0}" = "0" ]; then
	tries=0

	while kill -0 "$length_pid" 2>/dev/null && [ "$tries" -lt 10 ]; do
		sleep 0.5
		tries=$((tries + 1))
	done

	wait "$length_pid" 2>/dev/null || true

	late="$(cat "$work/length" 2>/dev/null || true)"

	if [ "${late:-0}" -gt 0 ] 2>/dev/null; then
		jq -cn --argjson d "${late%.*}" '{duration: $d, syncedLyrics: "", plainLyrics: ""}'
	fi
fi
