#!/usr/bin/env bash
set -euo pipefail

dir="${HOME}/screenshots"
mkdir -p "$dir"

out="${dir}/$(date +%Y-%m-%d_%H-%M-%S)_region.png"

if ! qs -c moxi ipc call screenshot region "$out"; then
	if command -v notify-send >/dev/null 2>&1; then
		timeout 2 notify-send -u critical -a screenshot "Screenshot failed" "quickshell is not running"
	fi
	exit 1
fi
