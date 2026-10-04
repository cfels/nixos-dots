#!/usr/bin/env bash

set -e

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
USER_NAME="${DOTS_USER:-${SUDO_USER:-$(id -un)}}"
if id -u "$USER_NAME" >/dev/null 2>&1; then
  USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
  USER_HOME="${USER_HOME:-/home/$USER_NAME}"
  if [ "$USER_NAME" = "$(id -un)" ]; then
    stow_cmd=(stow)
    mkdir_cmd=(mkdir -p)
  else
    stow_cmd=(sudo stow)
    mkdir_cmd=(sudo mkdir -p)
    CHOWN_USER=1
  fi
else
  USER_HOME="/home/$USER_NAME"
  stow_cmd=(sudo stow)
  mkdir_cmd=(sudo mkdir -p)
  CHOWN_USER=1
fi
HOST_NAME="$(hostname)"

# delete and make dirs
#del dirs
sudo rm -rf "$USER_HOME/.config"
sudo rm -rf "$USER_HOME/.icons"
#make dirs
"${mkdir_cmd[@]}" "$USER_HOME/.config"
"${mkdir_cmd[@]}" "$USER_HOME/.icons"

# install stow
#nix-shell -p stow git wget aria2

# stow
cd "$REPO/Configs/"
"${stow_cmd[@]}" --target="$USER_HOME" config local walls

# make baked-in author paths (/home/moxiu/...) point at this machine's user.
# stow links these files into the repo, so replace the link with a real copy
# first - otherwise sed would rewrite the repository file.
for f in kscreenlockerrc plasmarc spectaclerc; do
  target="$USER_HOME/.config/$f"

  [ -e "$target" ] || continue
  if [ -L "$target" ]; then
    source="$(readlink -f "$target")"
    rm -f "$target"
    sed "s|/home/moxiu|$USER_HOME|g" "$source" > "$target"
  fi
done

# symlnk /etc/nixos
sudo rm -rf /etc/nixos
sudo ln -s "$REPO/Configs/nixos" /etc/nixos
if [ -f "$USER_HOME/dots-backup/nixos/hardware-configuration.nix" ]; then
  cp "$USER_HOME/dots-backup/nixos/hardware-configuration.nix" "$REPO/Configs/nixos/hardware-configuration.nix"
else
  nixos-generate-config --show-hardware-config > "$REPO/Configs/nixos/hardware-configuration.nix"
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
} > "$REPO/Configs/nixos/luks.nix"

printf '"%s"\n' "$USER_NAME" > "$REPO/Configs/nixos/username.nix"
printf '"%s"\n' "$HOST_NAME" > "$REPO/Configs/nixos/hostname.nix"
sudo git config --global --add safe.directory "$REPO"
sudo cp -r "$REPO/Configs/config/.config/nvim/" /root/.config/
fc-cache -f -v
if ! sudo nixos-rebuild switch --flake "/etc/nixos#${USER_NAME}"; then
  echo "nixos-rebuild switch failed - falling back to direct activation"
  echo "(usually a systemd too old for 'systemd-run --output=cat', needs systemd >= 253)"
  sudo NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration switch
fi
[ -z "${CHOWN_USER:-}" ] || sudo chown -R "$USER_NAME" "$USER_HOME"
