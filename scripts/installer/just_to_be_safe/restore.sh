#!/usr/bin/env bash

set -euo pipefail
umask 077

source "$(dirname -- "${BASH_SOURCE[0]}")/../common.sh"
dots_resolve_user
dots_require_root "$0" "$@"
[[ "$USER_EXISTS" == 1 ]] || { dots_error "restore requires an existing user"; exit 1; }
dots_lock

backup="$USER_HOME/dots-backup"
dots_validate_backup "$backup"
system_source="$backup/nixos"
if [[ -d /etc/nixos.bak && ! -L /etc/nixos.bak ]]; then
  dots_validate_system_source /etc/nixos.bak
  system_source=/etc/nixos.bak
fi

dots_begin_transaction restore
dots_copy_directory "$system_source" "$TX_SYSTEM/nixos"
for index in 1 2 3; do
  item="${BACKUP_ITEMS[$index]}"
  [[ "${BACKUP_STATES[$index]}" == present ]] || continue
  dots_copy_directory "$backup/$item" "$TX_HOME/$item"
  sudo chown -R -P -h -- "$USER_NAME" "$TX_HOME/$item"
done

printf 'publishing\n' > "$TX_HOME/status"
for item in .config .local .icons; do
  dots_replace "$USER_HOME/$item" "$TX_HOME/$item"
done
dots_replace /etc/nixos "$TX_SYSTEM/nixos"

echo "restore DONE!"
