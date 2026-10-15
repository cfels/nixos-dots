#!/usr/bin/env bash

set -e

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTS_REPO="$REPO"

mode=""
requested_user=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rollback_restore|-rr) mode="rollback"; shift ;;
    --help|-h) mode="help"; shift ;;
    -u|--user) requested_user="${2:-}"; shift 2 2>/dev/null || shift ;;
    *) shift ;;
  esac
done

cat <<"EOF"
   _  _______  __    ___  ____  __________  _____  _______________   __   __   _______ 
  / |/ /  _/ |/_/___/ _ \/ __ \/_  __/ __/ /  _/ |/ / __/_  __/ _ | / /  / /  / __/ _ \
 /    // /_>  </___/ // / /_/ / / / _\ \  _/ //    /\ \  / / / __ |/ /__/ /__/ _// , _/
/_/|_/___/_/|_|   /____/\____/ /_/ /___/ /___/_/|_/___/ /_/ /_/ |_/____/____/___/_/|_| v1.0
                                                                                          by moxiu (cfels on github)
EOF

# restore and rollback flag
if [ "$mode" = "rollback" ]; then
  echo "rolling u back and restoring..."
  "$REPO/scripts/installer/just_to_be_safe/rollback.sh"
  "$REPO/scripts/installer/just_to_be_safe/restore.sh"
  echo "both script's finished it's work"
  exit 0
fi

# help flag
if [ "$mode" = "help" ]; then
  cat <<"EOF"

--[[
   _  _______  __    ___  ____  __________  __ ________   ___ 
  / |/ /  _/ |/_/___/ _ \/ __ \/_  __/ __/ / // / __/ /  / _ \
 /    // /_>  </___/ // / /_/ / / / _\ \  / _  / _// /__/ ___/
/_/|_/___/_/|_|   /____/\____/ /_/ /___/ /_//_/___/____/_/    
                                                              
--]]

  USAGE:
   --help, -h = show help (who would guess that right?)
   --rollback_restore, -rr = nix rollback and restore ur configs
   --user, -u <name> = install for this username (asked for if not given)

that's it
EOF
  exit 0
fi

# username to install for
default_user="${SUDO_USER:-$(id -un)}"
USER_NAME="${requested_user:-${DOTS_USER:-}}"
if [ -z "$USER_NAME" ]; then
  printf 'install for which username? [%s]: ' "$default_user"
  read -r USER_NAME || true
  USER_NAME="${USER_NAME:-$default_user}"
fi
if ! printf '%s' "$USER_NAME" | grep -Eq '^[a-zA-Z0-9_.][a-zA-Z0-9_.-]*$'; then
  echo "'$USER_NAME' is not a valid username"
  exit 1
fi
existing_uid="$(id -u "$USER_NAME" 2>/dev/null)" || existing_uid=""
if [ -n "$existing_uid" ]; then
  existing_shell="$(getent passwd "$USER_NAME" | cut -d: -f7)"
  case "$existing_shell" in
    *nologin|*/false)
      echo "'$USER_NAME' is a system account (shell $existing_shell), pick a normal user or a new name"
      exit 1
      ;;
  esac
  if [ "$existing_uid" -lt 1000 ]; then
    echo "'$USER_NAME' is a system account (uid $existing_uid), pick a normal user or a new name"
    exit 1
  fi
fi
if ! id -u "$USER_NAME" >/dev/null 2>&1; then
  echo "user '$USER_NAME' does not exist yet, the rebuild will create it"
  printf 'type the username again to confirm: '
  read -r confirm_user || true
  if [ "$confirm_user" != "$USER_NAME" ]; then
    echo "usernames do not match, aborting"
    exit 1
  fi
fi
export DOTS_USER="$USER_NAME"
echo "installing for user '$USER_NAME'"

echo "check stuff"
"$REPO/scripts/installer/checkstuff.sh"

echo "execute backup script"
"$REPO/scripts/installer/just_to_be_safe/backup.sh"

echo "apply configs"
"$REPO/scripts/installer/applyconfigs_stow.sh"

echo "DONE! with no issue's i guess"
