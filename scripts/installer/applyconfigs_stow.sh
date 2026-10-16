#!/usr/bin/env bash

set -euo pipefail
umask 077

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO/scripts/installer/common.sh"
dots_resolve_user
dots_require_root "$0" "$@"
dots_lock
dots_validate_backup "$USER_HOME/dots-backup"
new_user=$((1 - USER_EXISTS))
HOST_NAME="$(hostname)"

dots_begin_transaction apply
mkdir -m 755 "$TX_HOME/.config" "$TX_HOME/.icons"
stow_cmd=(stow)
if [[ "$USER_EXISTS" == 1 ]]; then
  sudo chown -h -- "$USER_NAME" "$TX_HOME/.config" "$TX_HOME/.icons"
  stow_cmd=(sudo -u "$USER_NAME" stow)
fi
dots_replace "$USER_HOME/.config" "$TX_HOME/.config"
dots_replace "$USER_HOME/.icons" "$TX_HOME/.icons"

"${stow_cmd[@]}" --simulate \
  --dir="$REPO/Configs" \
  --target="$USER_HOME" \
  config local walls

"${stow_cmd[@]}" \
  --dir="$REPO/Configs" \
  --target="$USER_HOME" \
  config local walls

for f in kscreenlockerrc plasmarc spectaclerc; do
  target="$USER_HOME/.config/$f"

  [ -e "$target" ] || continue
  if [ -L "$target" ]; then
    source="$(readlink -f "$target")"
    rm -f "$target"
    sed "s|/home/moxiu|$USER_HOME|g" "$source" >"$target"
  fi
done

if [[ "$USER_EXISTS" == 1 ]]; then
  dots_own_stowed_paths "$REPO"
fi

ln -s "$REPO/Configs/nixos" "$TX_SYSTEM/nixos"
dots_replace /etc/nixos "$TX_SYSTEM/nixos"
if [[ ! -e /etc/nixos.bak && ! -L /etc/nixos.bak ]]; then
  dots_copy_directory "$USER_HOME/dots-backup/nixos" "$TX_SYSTEM/nixos.bak"
  dots_replace /etc/nixos.bak "$TX_SYSTEM/nixos.bak"
fi
if [ -f "$USER_HOME/dots-backup/nixos/hardware-configuration.nix" ]; then
  cp "$USER_HOME/dots-backup/nixos/hardware-configuration.nix" "$REPO/Configs/nixos/hardware-configuration.nix"
else
  nixos-generate-config --show-hardware-config >"$REPO/Configs/nixos/hardware-configuration.nix"
fi

# luks devices of this machine (skips ones the hardware config already opens)
{
  echo "{"
  findmnt -rno SOURCE | sed 's/\[.*$//' | sort -u | while read -r src; do
    case "$src" in
    /dev/mapper/*) ;;
    *) continue ;;
    esac
    map_name="$(basename "$src")"
    dm_uuid="$(cat "/sys/class/block/$map_name/dm/uuid" 2>/dev/null)" || continue
    case "$dm_uuid" in
    CRYPT-LUKS*) ;;
    *) continue ;;
    esac
    slave="$(basename /sys/class/block/"$map_name"/slaves/* 2>/dev/null)"
    luks_uuid="$(blkid -s UUID -o value "/dev/$slave" 2>/dev/null)"
    [ -n "$luks_uuid" ] || continue
    grep -q "luks.devices.*$luks_uuid" "$REPO/Configs/nixos/hardware-configuration.nix" 2>/dev/null && continue
    echo "  \"luks-$luks_uuid\" = { device = \"/dev/disk/by-uuid/$luks_uuid\"; };"
  done
  echo "}"
} >"$REPO/Configs/nixos/luks.nix"

printf '"%s"\n' "$USER_NAME" >"$REPO/Configs/nixos/username.nix"
printf '"%s"\n' "$HOST_NAME" >"$REPO/Configs/nixos/hostname.nix"
sudo git config --global --add safe.directory "$REPO"
sudo cp -r "$REPO/Configs/config/.config/nvim/" /root/.config/
fc-cache -f -v
dots_commit_transaction
if ! sudo nixos-rebuild switch --flake "/etc/nixos#${USER_NAME}"; then
  echo "nixos-rebuild switch failed - falling back to direct activation"
  echo "(usually a systemd too old for 'systemd-run --output=cat', needs systemd >= 253)"
  sudo NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration switch
fi
if [[ "$new_user" == 1 ]]; then
  sudo chown -h -- "$USER_NAME" "$USER_HOME"
  dots_own_stowed_paths "$REPO"
fi
