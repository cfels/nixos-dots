#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
restore=0
[ "${2:-}" != "--restore" ] || restore=1
[ -n "$image" ] || exit 1
[ -f "$image" ] || exit 1

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
runtime="${XDG_RUNTIME_DIR:-${HOME}/.cache}/moxi-wallpaper"
mkdir -p "$runtime"
chmod 700 "$runtime"
# Switching and restoring share one lock; renderer children must not inherit it.
exec 9>"${runtime}/switch.lock"
flock 9

extension="${image##*.}"
extension="${extension,,}"

palette_source="$image"
if [[ "$image" == *.premiumwall.json ]]; then
	palette_source="$(python3 "$SCRIPT_DIR/premium-wallpaper.py" preview "$image")"
fi

is_video=0
case "$extension" in
mp4 | m4v | webm | mkv | mov | avi) is_video=1 ;;
esac

frame_dir() {
	printf '%s' "${HOME}/.cache/moxi-wallpapers"
}

frame_for() {
	local file="$1" key frame

	key="$(printf '%s' "$file" | md5sum | cut -c1-16)"
	frame="$(frame_dir)/${key}.first.png"

	if [ ! -s "$frame" ] || [ "$file" -nt "$frame" ]; then
		mkdir -p "$(frame_dir)"

		# Palette extraction runs after playback has started.
		ffmpeg -y -loglevel error -i "$file" -frames:v 1 \
			-vf "scale='min(3840,iw)':-2" "$frame" || return 1
	fi

	[ -s "$frame" ] || return 1
	printf '%s' "$frame"
}

# Completion means the incoming wallpaper has fully covered the outgoing video.
python3 "$SCRIPT_DIR/wallpaper-render.py" "$image"

# Retire legacy renderers only after a successful first handoff.
if [ ! -e "${runtime}/legacy-retired" ]; then
	pkill -u "$UID" -f '^([^ ]*/)?[.]?mpvpaper(-wrapped|-holder)?([[:space:]]|$)' >/dev/null 2>&1 || true
	for tool in awww swww; do
		if command -v "$tool" >/dev/null 2>&1; then
			"$tool" kill >/dev/null 2>&1 || true
		fi
	done
	rm -f -- "${runtime}/video.sock" "${runtime}/video.pid"
	touch "${runtime}/legacy-retired"
fi

mkdir -p "${HOME}/.cache"
printf '%s\n' "$image" >"${HOME}/.cache/current-wallpaper"

# Unlock/startup only needs the wallpaper, not a palette or shell reload.
[ "$restore" -eq 0 ] || exit 0

if command -v matugen >/dev/null 2>&1; then
	matugen_ok=0

	if [ "$is_video" -eq 0 ]; then
		matugen image "$palette_source" --mode dark --prefer saturation >/dev/null 2>&1 && matugen_ok=1 || true
	fi

	if [ "$matugen_ok" -eq 0 ]; then
		frame="$(frame_for "$image" || true)"

		if [ -n "$frame" ]; then
			matugen image "$frame" --mode dark --prefer saturation >/dev/null 2>&1 && matugen_ok=1 || true
		fi
	fi

	if [ "$matugen_ok" -eq 1 ]; then
		# Theme.qml watches colors.json; reloading the shell would discard queued choices.
		command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
	fi
fi
