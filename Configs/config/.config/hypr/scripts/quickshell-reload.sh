#!/usr/bin/env bash
set -euo pipefail

export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-kde}"
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-breeze}"

case ":${QT_PLUGIN_PATH:-}:" in
*:/run/current-system/sw/lib/qt-6/plugins:*)
	;;
*)
	export QT_PLUGIN_PATH="/run/current-system/sw/lib/qt-6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
	;;
esac

config="${1:-moxi}"
state="${XDG_RUNTIME_DIR:-/tmp}/quickshell"

prune() {
	local link pid target

	[ -d "${state}/by-pid" ] || return 0

	for link in "${state}"/by-pid/*; do
		[ -L "$link" ] || continue

		pid="${link##*/}"

		if kill -0 "$pid" 2>/dev/null; then
			continue
		fi

		target="$(readlink -f "$link" 2>/dev/null || true)"

		case "$target" in
			"${state}"/by-id/*) rm -rf "$target" ;;
		esac

		rm -f "$link"
	done

	for link in "${state}"/by-shell/*/* "${state}"/by-path/*; do
		[ -L "$link" ] || continue
		[ -e "$link" ] || rm -f "$link"
	done
}

if timeout 3 qs -c "$config" ipc call shell reload >/dev/null 2>&1; then
	exit 0
fi

prune

pkill quickshell >/dev/null 2>&1 || true
sleep 0.2

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
	if hyprctl dispatch "hl.dsp.exec_cmd(\"qs -c $config\")" >/dev/null 2>&1; then
		exit 0
	fi
fi

setsid qs -c "$config" -d >/dev/null 2>&1 < /dev/null &
