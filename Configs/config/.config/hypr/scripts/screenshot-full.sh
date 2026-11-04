#!/usr/bin/env bash
set -euo pipefail

dir="$(python3 "${HOME}/.config/hypr/scripts/moxi-settings.py" get desktop.screenshotDirectory)"
mkdir -p "$dir"

out="${dir}/$(date +%Y-%m-%d_%H-%M-%S)_screen.png"

exec "${HOME}/.config/hypr/scripts/screenshot-capture.sh" full "$out"
