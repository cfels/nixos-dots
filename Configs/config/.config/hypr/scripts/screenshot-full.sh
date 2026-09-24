#!/usr/bin/env bash
set -euo pipefail

dir="${HOME}/screenshots"
mkdir -p "$dir"

out="${dir}/$(date +%Y-%m-%d_%H-%M-%S)_screen.png"

exec "${HOME}/.config/hypr/scripts/screenshot-capture.sh" full "$out"
