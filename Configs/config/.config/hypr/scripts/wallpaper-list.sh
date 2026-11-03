#!/usr/bin/env bash
set -euo pipefail

dir="${HOME}/walls"
cache="${HOME}/.cache/moxi-wallpapers"
mkdir -p "$cache"

key_for() {
	printf '%s' "$1" | md5sum | cut -c1-16
}

# FFmpeg must leave the surrounding filename-reading loop's stdin untouched.
thumb_for() {
	local file="$1" key thumb

	key="$(key_for "$file")"
	thumb="${cache}/${key}.jpg"

	if [ ! -s "$thumb" ]; then
		ffmpeg -nostdin -y -loglevel error -ss 1 -i "$file" -frames:v 1 \
			-vf "scale=640:-2" -q:v 3 "$thumb" >/dev/null 2>&1 ||
			ffmpeg -nostdin -y -loglevel error -i "$file" -frames:v 1 \
				-vf "scale=640:-2" -q:v 3 "$thumb" >/dev/null 2>&1 || true
	fi

	if [ -s "$thumb" ]; then printf '%s' "$thumb"; fi
}

preview_for() {
	local file="$1" start="${2:-1}" length="${3:-3}" key preview temporary

	key="$(key_for "$file")"
	preview="${cache}/${key}.gif"

	if [ ! -s "$preview" ] || [ "$file" -nt "$preview" ]; then
		temporary="$(mktemp "${cache}/.${key}.XXXXXX.gif")"
		if ffmpeg -nostdin -y -loglevel error -ss "$start" -t "$length" -i "$file" \
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
		poster="$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/premium-wallpaper.py" preview "$file")" || continue
		showcase="$(python3 "$(dirname -- "${BASH_SOURCE[0]}")/premium-wallpaper.py" preview "$file" --animated)" || continue
		printf '%s\t%s\t%s\n' "$file" "$poster" "$(preview_for "$showcase" 0 6)"
		;;
	*.mp4 | *.m4v | *.webm | *.mkv | *.mov | *.avi)
		printf '%s\t%s\t%s\n' "$file" "$(thumb_for "$file")" "$(preview_for "$file")"
		;;
	*) printf '%s\t\t\n' "$file" ;;
	esac
done <<<"$list"
