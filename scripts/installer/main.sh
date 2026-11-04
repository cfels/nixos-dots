#!/usr/bin/env bash

set -e

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTS_REPO="$REPO"
source "$REPO/scripts/installer/common.sh"
original_args=("$@")

mode=""
requested_user=""
secure_boot=0
while [ $# -gt 0 ]; do
  case "$1" in
  --rollback_restore | -rr)
    mode="rollback"
    shift
    ;;
  --help | -h)
    mode="help"
    shift
    ;;
  -u | --user)
    [[ $# -ge 2 && -n "$2" ]] || {
      dots_error "$1 requires a username"
      exit 1
    }
    requested_user="$2"
    shift 2
    ;;
  --secure-boot)
    secure_boot=1
    shift
    ;;
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
   --rollback_restore, -rr = restore ur configs, then activate the restored system
   --user, -u <name> = install for this username (asked for if not given)
   --secure-boot = prepare signed GRUB and a boot entry after installation
                   firmware key enrollment and reboot remain manual

that's it
EOF
  exit 0
fi

default_user="${SUDO_USER:-$(id -un)}"
USER_NAME="${requested_user:-${DOTS_USER:-}}"
if [ "$mode" = "rollback" ]; then
  export DOTS_USER="${USER_NAME:-$default_user}"
  dots_resolve_user
  dots_require_root "$0" "${original_args[@]}"
  dots_lock
  echo "restoring ur configs and activating the restored system..."
  "$REPO/scripts/installer/just_to_be_safe/restore.sh"
  "$REPO/scripts/installer/just_to_be_safe/rollback.sh"
  echo "both script's finished it's work"
  exit 0
fi

if [ -z "$USER_NAME" ]; then
  printf 'install for which username? [%s]: ' "$default_user"
  read -r USER_NAME || true
  USER_NAME="${USER_NAME:-$default_user}"
fi
export DOTS_USER="$USER_NAME"
dots_resolve_user
if [[ "$USER_EXISTS" == 0 ]]; then
  echo "user '$USER_NAME' does not exist yet, the rebuild will create it"
  printf 'type the username again to confirm: '
  read -r confirm_user || true
  if [ "$confirm_user" != "$USER_NAME" ]; then
    echo "usernames do not match, aborting"
    exit 1
  fi
fi
echo "installing for user '$USER_NAME'"

if [[ -f "$REPO/.gitmodules" ]]; then
  echo "fetching wallpapers"
  git -C "$REPO" submodule update --init --recursive -- Configs/walls/walls
fi

echo "check stuff"
"$REPO/scripts/installer/checkstuff.sh"

echo "execute backup script"
"$REPO/scripts/installer/just_to_be_safe/backup.sh"

echo "apply configs"
"$REPO/scripts/installer/applyconfigs_stow.sh"

if [[ "$secure_boot" == 1 ]]; then
  echo "preparing GRUB Secure Boot"
  if ! sudo /run/current-system/sw/bin/grub-secure-setup; then
    echo "Desktop installation completed, but Secure Boot preparation failed." >&2
    echo "Fix the reported issue, then retry: sudo grub-secure-setup" >&2
    exit 1
  fi
else
  echo "Optional GRUB Secure Boot setup: sudo grub-secure-setup"
fi

echo "DONE! with no issue's i guess"

# count successful install and send it to endpoint
curl --disable --silent --fail --max-time 3 --request POST \
  --user-agent '' --output /dev/null https://stats.vacpro.fyi/install >/dev/null 2>&1 || :
