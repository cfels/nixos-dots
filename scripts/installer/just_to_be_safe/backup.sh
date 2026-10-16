#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(dirname -- "${BASH_SOURCE[0]}")/../common.sh"
dots_resolve_user
dots_require_root "$0" "$@"
if [[ ! -d "$USER_HOME" ]]; then
  sudo mkdir -p -m 755 -- "$USER_HOME"
  if [[ "$USER_EXISTS" == 1 ]]; then
    sudo chown -h -- "$USER_NAME" "$USER_HOME"
  fi
fi
dots_lock

backup="$USER_HOME/dots-backup"
if [[ -e "$backup" || -L "$backup" ]]; then
  dots_validate_backup "$backup"
fi

stage="$(sudo mktemp -d "$USER_HOME/.dots-backup.XXXXXX")"
trap 'printf "Backup staging retained at %s\n" "$stage" >&2' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'moxi-backup-v1\n' > "$stage/.dots-manifest"

for item in nixos .config .local .icons; do
  if [[ "$item" == nixos ]]; then
    source=/etc/nixos
    if [[ -d "$backup/nixos" ]]; then
      source="$backup/nixos"
      echo "original /etc/nixos already backed up, keeping it"
    fi
  else
    source="$USER_HOME/$item"
  fi
  echo "backup $item"
  if [[ -e "$source" || -L "$source" ]]; then
    dots_copy_directory "$source" "$stage/$item"
    printf '%s\tpresent\n' "$item" >> "$stage/.dots-manifest"
  elif [[ "$item" != nixos ]]; then
    printf '%s\tabsent\n' "$item" >> "$stage/.dots-manifest"
  else
    dots_error "missing system configuration: $source"
    exit 1
  fi
done
dots_validate_backup "$stage"

if [[ -d "$backup" ]]; then
  sudo mv --exchange --no-copy -T -- "$stage" "$backup"
  echo "previous backup retained at $stage"
else
  sudo mv --no-copy -T -- "$stage" "$backup"
fi
trap - EXIT

echo "backup DONE!"
