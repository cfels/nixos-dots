#!/usr/bin/env bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/../common.sh"
dots_resolve_user
dots_require_root "$0" "$@"
dots_lock
[[ "$USER_EXISTS" == 1 ]] || {
  dots_error "restored user is missing"
  exit 1
}
dots_validate_system_source /etc/nixos

echo "activating restored system..."
if [[ -f /etc/nixos/flake.nix ]]; then
  sudo nixos-rebuild switch --flake "/etc/nixos#$USER_NAME"
else
  sudo nixos-rebuild switch
fi
echo "restored system activated"
