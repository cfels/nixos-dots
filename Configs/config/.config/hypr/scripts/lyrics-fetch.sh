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
WANT_SECS="$(printf '%s' "${length%%.*}" | sed -e 's/[^0-9]//g')"
[ -n "$WANT_SECS" ] || WANT_SECS=0

JQ_MATCH='
def norm: ascii_downcase | gsub("[^\\p{L}\\p{N}]+"; " ") | gsub("^ +| +$"; "");
def toks: norm | split(" ") | map(select(length > 0));
def strip: gsub("\\([^)]*\\)|\\[[^\\]]*\\]"; " ") | gsub(" +"; " ") | gsub("^ +| +$"; "");
def jac($a; $b):
	($a - ($a - $b) | length) as $hit
	| (($a | length) + ($b | length) - $hit) as $all
	| if $all <= 0 then 0 else $hit / $all end;
def shared($a; $b): ($a - ($a - $b) | length);
def adiff: if . < 0 then -. else . end;
($title | strip | toks) as $wantT
| ($artist | toks) as $wantA
| (($dur // 0) | if . < 0 then 0 else . end) as $wantD
| [ .[]
	| . as $c
	| (($c.title // "") | strip | toks) as $ct
	| (($c.artist // "") | strip | toks) as $ca
	| ($ct == $wantT) as $sameTitle
	| (($wantT | length) >= 2 and ($wantT - $ct | length) == 0) as $wantSub
	| (($ct | length) >= 2 and ($ct - $wantT | length) == 0) as $ctSub
	| jac($ct; $wantT) as $ts
	| shared($ca; $wantA) as $as
	| select(($wantT | length) > 0 and ($sameTitle or $wantSub or $ctSub or $ts >= 0.6))
	| select(($wantA | length) == 0 or $as >= 1)
	| $c + {
		score: (($ts * 3)
			+ (if $sameTitle then 1 else 0 end)
			+ (if $as >= 1 then 0.6 else 0 end)
			+ (if (($c.synced // "") | length) > 0 then 0.4 else 0 end)
			+ (if ($wantD > 0 and ($c.duration // 0) > 0)
				then ((($c.duration // 0) - $wantD) | adiff) as $dd
					| if $dd <= 3 then 1 elif $dd <= 10 then 0.2 else -1 end
				else 0 end))
	}
]
| sort_by(-.score)
| .[0] // {}
'

pick() {
	jq -c --arg title "$title" --arg artist "$artist" --argjson dur "$WANT_SECS" "$JQ_MATCH" 2>/dev/null || printf '{}'
}

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
		jq -c 'if type == "array" then [ .[] | {title: (.trackName // ""), artist: (.artistName // ""), duration: (.duration // 0), synced: (.syncedLyrics // ""), plain: (.plainLyrics // "")} ] else [] end' 2>/dev/null |
		pick |
		jq -c '{duration: (.duration // 0), syncedLyrics: (.synced // ""), plainLyrics: (.plain // "")}' 2>/dev/null || true
}

prov_netease() {
	local search picked id ms lyric

	search="$(net -G --data-urlencode "s=$QUERY" --data-urlencode "type=1" --data-urlencode "limit=8" "https://music.163.com/api/search/get")"
	search="$(printf '%s' "$search" | jq -c '[(.result.songs // [])[] | {id: .id, title: (.name // ""), artist: ([.artists[]?.name] | join(" ")), duration: (((.duration // 0) / 1000) | floor)}]' 2>/dev/null || printf '[]')"

	picked="$(printf '%s' "$search" | pick)"
	id="$(printf '%s' "$picked" | jq -r '.id // empty' 2>/dev/null || true)"
	[ -n "$id" ] || return 0

	ms="$(printf '%s' "$picked" | jq -r '((.duration // 0) * 1000) | floor' 2>/dev/null || true)"
	lyric="$(net "https://music.163.com/api/song/lyric?id=${id}&lv=1&kv=1&tv=-1")"

	printf '%s' "$lyric" | jq -c --argjson ms "${ms:-0}" '{
		duration: (($ms / 1000) | floor),
		syncedLyrics: (.lrc.lyric // ""),
		plainLyrics: ((.lrc.lyric // "") | gsub("\\[[0-9:.]+\\]"; ""))
	}' 2>/dev/null || true
}

prov_qq() {
	local search picked mid secs lyric

	search="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "w=$QUERY" --data-urlencode "p=1" --data-urlencode "n=8" --data-urlencode "format=json" "https://c.y.qq.com/soso/fcgi-bin/client_search_cp")"
	search="$(printf '%s' "$search" | jq -c '[(.data.song.list // [])[] | {mid: .songmid, title: (.songname // ""), artist: ([.singer[]?.name] | join(" ")), duration: (.interval // 0)}]' 2>/dev/null || printf '[]')"

	picked="$(printf '%s' "$search" | pick)"
	mid="$(printf '%s' "$picked" | jq -r '.mid // empty' 2>/dev/null || true)"
	[ -n "$mid" ] || return 0

	secs="$(printf '%s' "$picked" | jq -r '.duration // 0' 2>/dev/null || true)"
	lyric="$(net -H 'Referer: https://y.qq.com/' -G --data-urlencode "songmid=$mid" --data-urlencode "format=json" --data-urlencode "nobase64=1" --data-urlencode "g_tk=5381" "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")"

	printf '%s' "$lyric" | jq -c --argjson secs "${secs:-0}" '{
		duration: ($secs // 0),
		syncedLyrics: (.lyric // ""),
		plainLyrics: ""
	}' 2>/dev/null || true
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
	}'
}

prov_lyricsovh() {
	local body

	body="$(net "https://api.lyrics.ovh/v1/$(printf '%s' "$artist" | jq -sRr @uri)/$(printf '%s' "$title" | jq -sRr @uri)")"

	printf '%s' "$body" | jq -c '{duration: 0, syncedLyrics: "", plainLyrics: (.lyrics // "")}' 2>/dev/null || true
}

genius_search() {
	net -G --data-urlencode "q=$1" "https://genius.com/api/search/multi" |
		jq -c '[.response.sections[]? | select(.type == "song") | .hits[]?.result | {url: (.url // ""), title: (.title // ""), artist: (.artist_names // .primary_artist.name // ""), duration: 0}]' 2>/dev/null || true
}

prov_genius() {
	local first_artist candidates url plain

	first_artist="$(printf '%s' "$artist" | sed -e 's/[[:space:]].*$//' -e 's/[^[:alnum:]]//g')"

	candidates="$(
		{
			[ -n "$first_artist" ] && genius_search "$title $first_artist"
			genius_search "$title"
		} | jq -c -s 'add // [] | unique_by(.url)' 2>/dev/null || true
	)"
	[ -n "$candidates" ] || return 0

	url="$(printf '%s' "$candidates" | pick | jq -r '.url // empty' 2>/dev/null || true)"
	[ -n "$url" ] || return 0

	plain="$(net "$url" | python3 -c '
import sys
from html.parser import HTMLParser

class LyricsParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.inside = False
        self.depth = 0
        self.exclude = None
        self.parts = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if not self.inside:
            if tag == "div" and attributes.get("data-lyrics-container") == "true":
                self.inside = True
                self.depth = 0
            return
        if tag == "div":
            self.depth += 1
            if self.exclude is None and attributes.get("data-exclude-from-selection") is not None:
                self.exclude = self.depth
        if tag == "br":
            self.parts.append("\n")

    def handle_startendtag(self, tag, attrs):
        if self.inside and tag == "br":
            self.parts.append("\n")
        else:
            self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if not self.inside or tag != "div":
            return
        if self.exclude is not None and self.depth == self.exclude:
            self.exclude = None
        if self.depth == 0:
            self.inside = False
            return
        self.depth -= 1

    def handle_data(self, data):
        if self.inside and self.exclude is None:
            self.parts.append(data)

parser = LyricsParser()
parser.feed(sys.stdin.read())
print("\n".join(line.strip() for line in "".join(parser.parts).split("\n") if line.strip()))
' 2>/dev/null || true)"
	[ -n "$plain" ] || return 0

	jq -cn --arg p "$plain" '{duration: 0, syncedLyrics: "", plainLyrics: $p}' 2>/dev/null || true
}

prov_apple() {
	[ -n "${APPLE_MUSIC_TOKEN:-}" ] || return 0

	local store="${APPLE_MUSIC_STOREFRONT:-us}" id body

	id="$(net -H "Authorization: Bearer $APPLE_MUSIC_TOKEN" -H 'Origin: https://music.apple.com' \
		-G --data-urlencode "term=$QUERY" --data-urlencode "types=songs" --data-urlencode "limit=8" \
		"https://amp-api.music.apple.com/v1/catalog/$store/search" |
		jq -c '[(.results.songs.data // [])[] | {id: .id, title: (.attributes.name // ""), artist: (.attributes.artistName // ""), duration: (((.attributes.durationInMillis // 0) / 1000) | floor)}]' 2>/dev/null |
		pick |
		jq -r '.id // empty' 2>/dev/null || true)"
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
	take "$(prov_genius)"
	[ -n "$plain" ] || take "$(prov_lyricsovh)"
	[ -n "$synced" ] || take "$(prov_apple)"
fi

if [ "$duration" = "0" ]; then
	iTunes_ms="$(net -G --data-urlencode "term=$QUERY" --data-urlencode "entity=song" --data-urlencode "limit=8" "https://itunes.apple.com/search" |
		jq -c '[(.results // [])[] | {title: (.trackName // ""), artist: (.artistName // ""), duration: (((.trackTimeMillis // 0) / 1000) | floor)}]' 2>/dev/null |
		pick |
		jq -r '((.duration // 0) * 1000) | floor' 2>/dev/null || echo 0)"

	if [ "${iTunes_ms%.*}" -gt 0 ] 2>/dev/null; then
		duration="$(awk -v ms="$iTunes_ms" 'BEGIN { printf "%d", ms / 1000 }')"
	else
		deezer_secs="$(net -G --data-urlencode "q=$QUERY" --data-urlencode "limit=8" "https://api.deezer.com/search" |
			jq -c '[(.data // [])[] | {title: (.title // ""), artist: (.artist.name // ""), duration: (.duration // 0)}]' 2>/dev/null |
			pick |
			jq -r '.duration // 0' 2>/dev/null || echo 0)"

		if [ "${deezer_secs%.*}" -gt 0 ] 2>/dev/null; then
			duration="${deezer_secs%.*}"
		fi
	fi
fi

CREDITS='(作词|作詞|作曲|编曲|編曲|produced by|written by|lyrics by)[[:space:]]*[:：]'
[ -n "$synced" ] && synced="$(printf '%s\n' "$synced" | grep -vE "$CREDITS" || true)"
[ -n "$plain" ] && plain="$(printf '%s\n' "$plain" | grep -vE "$CREDITS" || true)"

jq -cn --argjson d "${duration:-0}" --arg s "$synced" --arg p "$plain" \
	'{duration: $d, syncedLyrics: $s, plainLyrics: $p}'
