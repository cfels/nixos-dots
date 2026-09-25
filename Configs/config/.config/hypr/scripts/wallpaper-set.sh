#!/usr/bin/env bash
set -euo pipefail

image="${1:-}"
[ -n "$image" ] || exit 1
[ -f "$image" ] || exit 1

extension="${image##*.}"
extension="${extension,,}"

is_video=0
case "$extension" in
mp4 | m4v | webm | mkv | mov | avi) is_video=1 ;;
esac

resolve() {
	local name="$1"
	local path

	path="$(command -v "$name" 2>/dev/null || true)"
	if [ -n "$path" ]; then
		printf '%s' "$path"
		return 0
	fi

	path="$(ls -d /nix/store/*-"${name}"-[0-9]*/bin/"${name}" 2>/dev/null | sort -V | tail -n 1 || true)"
	if [ -n "$path" ]; then
		printf '%s' "$path"
		return 0
	fi

	return 1
}

stop_video() {
	local player

	player="$(resolve mpvpaper || true)"

	if [ -n "$player" ]; then
		pkill -f "^${player}" >/dev/null 2>&1 || true
	fi

	pkill -f "bin/mpvpaper-holder" >/dev/null 2>&1 || true
}

frame_dir() {
	printf '%s' "${HOME}/.cache/moxi-wallpapers"
}

frame_for() {
	local file="$1" key frame

	key="$(printf '%s' "$file" | md5sum | cut -c1-16)"
	frame="$(frame_dir)/${key}.frame.jpg"

	if [ ! -s "$frame" ]; then
		mkdir -p "$(frame_dir)"

		ffmpeg -y -loglevel error -ss 1 -i "$file" -frames:v 1 \
			-vf "scale='min(3840,iw)':-2" -q:v 2 "$frame" >/dev/null 2>&1 ||
			ffmpeg -y -loglevel error -i "$file" -frames:v 1 \
				-vf "scale='min(3840,iw)':-2" -q:v 2 "$frame" >/dev/null 2>&1 || true
	fi

	if [ -s "$frame" ]; then printf '%s' "$frame"; fi
}

jump_pos() {
	case "$((RANDOM % 4))" in
	0) printf '0.0,0.0' ;;
	1) printf '1.0,0.0' ;;
	2) printf '0.0,1.0' ;;
	3) printf '1.0,1.0' ;;
	esac
}

stop_image_daemon() {
	if [ -n "${image_tool:-}" ]; then
		"$image_tool" kill >/dev/null 2>&1 || true
	fi

	pkill -f "bin/awww-daemon" >/dev/null 2>&1 || true
	pkill -f "bin/swww-daemon" >/dev/null 2>&1 || true
}

ensure_image_daemon() {
	[ -n "$daemon_tool" ] || return 1

	if pgrep -f "awww-daemon|swww-daemon" >/dev/null 2>&1; then
		return 0
	fi

	setsid "$daemon_tool" >/dev/null 2>&1 < /dev/null &
	sleep 0.5
}

apply_image() {
	local file="$1"

	[ -n "$image_tool" ] || return 1

	ensure_image_daemon || return 1

	"$image_tool" img "$file" \
		--transition-type grow \
		--transition-pos "$(jump_pos)" \
		--transition-duration 1 \
		--transition-fps 60
}

start_video() {
	local file="$1" player="$2" options="$3" attempt

	setsid "$player" -f -p -a FULL -o "$options" ALL "$file" >/dev/null 2>&1 < /dev/null &

	for attempt in 1 2 3 4 5 6 7 8 9 10; do
		if pgrep -f "^${player}" >/dev/null 2>&1; then
			return 0
		fi

		sleep 0.25
	done

	return 1
}

image_tool="$(resolve awww || resolve swww || true)"
daemon_tool="$(resolve awww-daemon || resolve swww-daemon || true)"

if [ "$is_video" -eq 1 ]; then
	player="$(resolve mpvpaper || true)"

	if [ -z "$player" ]; then
		notify-send "Wallpaper" "install mpvpaper to use video wallpapers" >/dev/null 2>&1 || true
		exit 1
	fi

	stop_video

	# awww and mpvpaper both paint the background layer, only one owns it at a
	# time. awww animates the switch into a still of the video first and mpvpaper
	# takes the layer over once it is rendering its own frames.
	frame="$(frame_for "$image" || true)"
	video_options="no-audio loop-file=inf hwdec=auto-safe really-quiet"

	if [ -n "$frame" ] && [ -n "$image_tool" ]; then
		apply_image "$frame" >/dev/null 2>&1 || true
		sleep 1.2
		video_options="${video_options} start=1"
	fi

	if ! start_video "$image" "$player" "$video_options"; then
		notify-send "Wallpaper" "could not start the video wallpaper" >/dev/null 2>&1 || true
		exit 1
	fi

	sleep 0.8
	stop_image_daemon
else
	stop_video

	[ -n "$image_tool" ] || exit 1

	apply_image "$image"
fi

mkdir -p "${HOME}/.cache"
printf '%s\n' "$image" > "${HOME}/.cache/current-wallpaper"

if command -v matugen >/dev/null 2>&1; then
	matugen_ok=0

	if [ "$is_video" -eq 0 ]; then
		matugen image "$image" --mode dark --prefer saturation >/dev/null 2>&1 && matugen_ok=1 || true
	fi

	if [ "$matugen_ok" -eq 0 ]; then
		frame="$(frame_for "$image" || true)"

		if [ -n "$frame" ]; then
			matugen image "$frame" --mode dark --prefer saturation >/dev/null 2>&1 && matugen_ok=1 || true
		fi
	fi

	if [ "$matugen_ok" -eq 1 ]; then
		"${HOME}/.config/hypr/scripts/quickshell-reload.sh" >/dev/null 2>&1 || true
		command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
	fi
fi
