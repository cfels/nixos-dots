#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec kitty --class moxi-updater --title 'NixOS-Dots updater  ' \
  --override initial_window_width=100c \
  --override initial_window_height=32c \
  --override remember_window_size=no \
  --override window_padding_width=18 \
  "$script_dir/update.sh"
