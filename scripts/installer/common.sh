#!/usr/bin/env bash

dots_error() {
  printf 'installer: %s\n' "$*" >&2
  return 1
}

dots_resolve_user() {
  USER_NAME="${DOTS_USER:-${SUDO_USER:-$(id -un)}}"
  [[ "$USER_NAME" =~ ^[a-zA-Z0-9_.][a-zA-Z0-9_.-]*$ ]] &&
    [[ "$USER_NAME" != . && "$USER_NAME" != .. ]] || {
    dots_error "invalid username '$USER_NAME'"
    return 1
  }

  local entry account password uid gid description shell canonical
  USER_EXISTS=0
  if entry="$(getent passwd "$USER_NAME")"; then
    IFS=: read -r account password uid gid description USER_HOME shell <<< "$entry"
    [[ "$account" == "$USER_NAME" && "$uid" =~ ^[0-9]+$ && "$uid" -ge 1000 ]] || {
      dots_error "'$USER_NAME' is not a normal user"
      return 1
    }
    case "$shell" in
      *nologin|*/false) dots_error "'$USER_NAME' is not a login account"; return 1 ;;
    esac
    USER_EXISTS=1
  else
    [[ "$?" == 2 ]] || { dots_error "could not resolve account '$USER_NAME'"; return 1; }
    USER_HOME="/home/$USER_NAME"
  fi

  [[ "$USER_HOME" == /* && "$USER_HOME" != *$'\n'* && "$USER_HOME" != *$'\t'* ]] || {
    dots_error "invalid home directory for '$USER_NAME'"
    return 1
  }
  canonical="$(realpath -m -- "$USER_HOME")" || return
  [[ "$canonical" == "$USER_HOME" ]] || {
    dots_error "home directory must be canonical and must not traverse symlinks: $USER_HOME"
    return 1
  }
  case "$USER_HOME" in
    /|/home|/root|/root/*|/etc|/etc/*|/nix|/nix/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*|/run|/run/*|/var|/tmp|/mnt|/media|/srv|/opt)
      dots_error "refusing unsafe home directory: $USER_HOME"
      return 1
      ;;
  esac
  [[ ! -e "$USER_HOME" || -d "$USER_HOME" ]] || {
    dots_error "home path is not a directory: $USER_HOME"
    return 1
  }
}

dots_require_root() {
  if [[ "$(id -u)" != 0 ]]; then
    exec sudo -- env DOTS_USER="$USER_NAME" bash "$@"
  fi
}

dots_lock() {
  local directory=/run/moxi-dots-installer
  [[ ! -L "$directory" ]] || {
    dots_error "installer lock directory must not be a symlink"
    return 1
  }
  mkdir -p -m 700 -- "$directory"
  if [[ "${DOTS_LOCK_USER:-}" != "$USER_NAME" || "$(readlink "/proc/$$/fd/9" 2>/dev/null || :)" != "$directory/operation.lock" ]]; then
    exec 9>"$directory/operation.lock"
  fi
  flock -n 9 || { dots_error "another installer operation is running"; return 1; }
  export DOTS_LOCK_USER="$USER_NAME"
  local recovery status
  for recovery in "$USER_HOME"/.dots-restore.* "$USER_HOME"/.dots-apply.*; do
    [[ -d "$recovery" ]] || continue
    status="$(cat "$recovery/status" 2>/dev/null)" || status=""
    case "$status" in
      complete|recovered) ;;
      *) dots_error "unfinished operation at $recovery; inspect its journal before retrying"; return 1 ;;
    esac
  done
}

dots_copy_directory() {
  local source="$1" destination="$2"
  [[ -d "$source" ]] || { dots_error "missing directory: $source"; return 1; }
  sudo cp -a -- "$source/." "$destination" || return
  sudo diff -qr --no-dereference -- "$source/." "$destination" || {
    dots_error "backup verification failed: $source"
    return 1
  }
}

dots_validate_system_source() {
  [[ -f "$1/flake.nix" || -f "$1/configuration.nix" ]] || {
    dots_error "system configuration has no flake.nix or configuration.nix: $1"
    return 1
  }
}

dots_validate_backup() {
  local backup="$1" item state
  local -a manifest
  [[ -d "$backup" && ! -L "$backup" ]] || {
    dots_error "backup must be a directory, not a symlink: $backup"
    return 1
  }
  BACKUP_ITEMS=(nixos .config .local .icons)
  BACKUP_STATES=(present present present present)
  if [[ -e "$backup/.dots-manifest" || -L "$backup/.dots-manifest" ]]; then
    [[ -f "$backup/.dots-manifest" && ! -L "$backup/.dots-manifest" ]] || {
      dots_error "backup manifest must be a regular file: $backup"
      return 1
    }
    mapfile -t manifest < "$backup/.dots-manifest"
    [[ "${#manifest[@]}" == 5 && "${manifest[0]:-}" == moxi-backup-v1 ]] || {
      dots_error "invalid backup manifest: $backup"
      return 1
    }
    for item in "${!BACKUP_ITEMS[@]}"; do
      case "${manifest[$((item + 1))]}" in
        "${BACKUP_ITEMS[$item]}"$'\t'present) BACKUP_STATES[$item]=present ;;
        "${BACKUP_ITEMS[$item]}"$'\t'absent) BACKUP_STATES[$item]=absent ;;
        *) dots_error "invalid backup manifest: $backup"; return 1 ;;
      esac
    done
  fi
  [[ "${BACKUP_STATES[0]}" == present ]] || {
    dots_error "backup must contain the system configuration: $backup"
    return 1
  }
  for item in "${!BACKUP_ITEMS[@]}"; do
    state="${BACKUP_STATES[$item]}"
    local source="$backup/${BACKUP_ITEMS[$item]}"
    if [[ "$state" == present ]]; then
      [[ -d "$source" && ! -L "$source" ]] || {
        dots_error "missing or linked backup directory: $source"
        return 1
      }
    elif [[ -e "$source" || -L "$source" ]]; then
      dots_error "backup contradicts its manifest: $source"
      return 1
    fi
  done
  dots_validate_system_source "$backup/nixos"
}

dots_begin_transaction() {
  TX_HOME="$(mktemp -d "$USER_HOME/.dots-$1.XXXXXX")"
  TX_SYSTEM="$(sudo mktemp -d "/etc/.dots-$1.XXXXXX")"
  TX_TARGETS=()
  TX_STAGED=()
  TX_ACTIONS=()
  TX_OLD=()
  TX_NEW=()
  TX_COMMITTED=0
  printf '%s\n' "$TX_SYSTEM" > "$TX_HOME/system-stage"
  printf 'preparing\n' > "$TX_HOME/status"
  trap dots_finish_transaction EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

dots_own_stowed_paths() {
  local repo="$1" package source relative target parent
  sudo chown -h -- "$USER_NAME" "$USER_HOME/.config" "$USER_HOME/.icons"
  for package in config local walls; do
    while IFS= read -r -d '' source; do
      relative="${source#"$repo/Configs/$package/"}"
      target="$USER_HOME/$relative"
      [[ -e "$target" || -L "$target" ]] || continue
      parent="$(realpath -m -- "$(dirname -- "$target")")"
      case "$parent/" in
        "$USER_HOME/"*) sudo chown -h -- "$USER_NAME" "$target" ;;
      esac
    done < <(find "$repo/Configs/$package" -mindepth 1 -print0)
  done
}

dots_inode() {
  if [[ -e "$1" || -L "$1" ]]; then
    stat -c '%d:%i' -- "$1"
  fi
}

dots_commit_transaction() {
  printf 'complete\n' > "$TX_HOME/status"
  TX_COMMITTED=1
}

dots_replace() {
  local target="$1" staged="$2" old new action
  old="$(dots_inode "$target")"
  new="$(dots_inode "$staged")"
  if [[ -n "$old" && -n "$new" ]]; then action=exchange
  elif [[ -n "$new" ]]; then action=install
  elif [[ -n "$old" ]]; then action=remove
  else return 0
  fi
  TX_TARGETS+=("$target")
  TX_STAGED+=("$staged")
  TX_ACTIONS+=("$action")
  TX_OLD+=("$old")
  TX_NEW+=("$new")
  printf '%s\t%s\t%s\t%s\t%s\n' "$action" "$target" "$staged" "$old" "$new" >> "$TX_HOME/journal"
  case "$action" in
    exchange) sudo mv --exchange --no-copy -T -- "$target" "$staged" ;;
    install) sudo mv --no-copy -T -- "$staged" "$target" ;;
    remove) sudo mv --no-copy -T -- "$target" "$staged" ;;
  esac
}

dots_finish_transaction() {
  local status=$? index current saved recovered=1
  trap - EXIT INT TERM
  set +e
  if [[ "$status" != 0 && "$TX_COMMITTED" == 0 ]]; then
    for ((index=${#TX_TARGETS[@]}-1; index>=0; index--)); do
      current="$(dots_inode "${TX_TARGETS[$index]}")"
      saved="$(dots_inode "${TX_STAGED[$index]}")"
      case "${TX_ACTIONS[$index]}" in
        exchange)
          if [[ "$current" == "${TX_NEW[$index]}" && "$saved" == "${TX_OLD[$index]}" ]]; then
            sudo mv --exchange --no-copy -T -- "${TX_TARGETS[$index]}" "${TX_STAGED[$index]}" || recovered=0
          elif [[ "$current" != "${TX_OLD[$index]}" || "$saved" != "${TX_NEW[$index]}" ]]; then recovered=0
          fi
          ;;
        install)
          if [[ "$current" == "${TX_NEW[$index]}" && -z "$saved" ]]; then
            sudo mv --no-copy -T -- "${TX_TARGETS[$index]}" "${TX_STAGED[$index]}" || recovered=0
          elif [[ -n "$current" || "$saved" != "${TX_NEW[$index]}" ]]; then recovered=0
          fi
          ;;
        remove)
          if [[ -z "$current" && "$saved" == "${TX_OLD[$index]}" ]]; then
            sudo mv --no-copy -T -- "${TX_STAGED[$index]}" "${TX_TARGETS[$index]}" || recovered=0
          elif [[ "$current" != "${TX_OLD[$index]}" || -n "$saved" ]]; then recovered=0
          fi
          ;;
      esac
    done
    if [[ "$recovered" == 1 ]]; then
      printf 'recovered\n' > "$TX_HOME/status"
    else
      printf 'manual-recovery-required\n' > "$TX_HOME/status"
      printf 'Automatic file recovery was incomplete. Inspect %s/journal before retrying.\n' "$TX_HOME" >&2
    fi
  else
    printf 'complete\n' > "$TX_HOME/status" || status=1
  fi
  printf 'Recovery files retained at %s and %s\n' "$TX_HOME" "$TX_SYSTEM" >&2
  exit "$status"
}
