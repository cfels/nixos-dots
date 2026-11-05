#!/usr/bin/env bash
set -euo pipefail

dir="${1:-${HOME}/walls}"
cached_only=0
case "${2:-}" in
--cached) cached_only=1 ;;
"") ;;
*)
	printf 'Usage: wallpaper-list.sh [directory] [--cached]\n' >&2
	exit 1
	;;
esac
cache="${HOME}/.cache/moxi-wallpapers"
mkdir -p "$cache"

key_for() {
	printf '%s' "$1" | md5sum | cut -c1-16
}

# FFmpeg must leave the surrounding filename-reading loop's stdin untouched.
thumb_for() {
	local file="$1" video="${2:-1}" key thumb temporary
	local -a seek=()
	[ "$video" -eq 0 ] || seek=(-ss 1)

	key="$(key_for "$file")"
	thumb="${cache}/${key}.jpg"

	if [ "$cached_only" -eq 0 ] && { [ ! -s "$thumb" ] || [ "$file" -nt "$thumb" ]; }; then
		temporary="$(mktemp "${cache}/.${key}.XXXXXX.jpg")"
		if nice -n 10 ffmpeg -nostdin -y -loglevel error "${seek[@]}" -i "$file" -frames:v 1 \
			-vf "scale=640:-2" -q:v 3 "$temporary" >/dev/null 2>&1 ||
			nice -n 10 ffmpeg -nostdin -y -loglevel error -i "$file" -frames:v 1 \
				-vf "scale=640:-2" -q:v 3 "$temporary" >/dev/null 2>&1; then
			mv -f -- "$temporary" "$thumb"
		else
			rm -f -- "$temporary"
		fi
	fi

	if [ -s "$thumb" ]; then printf '%s' "$thumb"; fi
}

preview_for() {
	local file="$1" start="${2:-1}" length="${3:-3}" key preview temporary

	key="$(key_for "$file")"
	preview="${cache}/${key}.gif"

	if [ "$cached_only" -eq 0 ] && { [ ! -s "$preview" ] || [ "$file" -nt "$preview" ]; }; then
		temporary="$(mktemp "${cache}/.${key}.XXXXXX.gif")"
		if nice -n 10 ffmpeg -nostdin -y -loglevel error -ss "$start" -t "$length" -i "$file" \
			-vf "fps=10,scale=560:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
			-an -loop 0 "$temporary" >/dev/null 2>&1; then
			mv -f -- "$temporary" "$preview"
		else
			printf 'Wallpaper preview: could not decode %s\n' "$file" >&2
			rm -f -- "$temporary"
		fi
	fi

	if [ -s "$preview" ]; then printf '%s' "$preview"; fi
}

list="$(
	find -L "$dir" -maxdepth 1 -type f 2>/dev/null |
		grep -Ei '\.(jpg|jpeg|png|webp|gif|mp4|m4v|webm|mkv|mov|avi|premiumwall\.json)$' |
		sort || true
)"

while IFS= read -r file; do
	[ -n "$file" ] || continue

	case "${file,,}" in
	*.premiumwall.json)
		metadata="$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/premium-wallpaper.py" describe "$file")" || continue
		poster="$(jq -r .posterPath <<<"$metadata")"
		showcase="$(jq -r .showcasePath <<<"$metadata")"
		printf '%s\t%s\t%s\t%s\n' "$file" "$poster" "$(preview_for "$showcase" 0 6)" "$metadata"
		;;
	*.mp4 | *.m4v | *.webm | *.mkv | *.mov | *.avi)
		printf '%s\t%s\t%s\n' "$file" "$(thumb_for "$file")" "$(preview_for "$file")"
		;;
	*) printf '%s\t%s\t\n' "$file" "$(thumb_for "$file" 0)" ;;
	esac
done <<<"$list"
