#!/usr/bin/env bash

USER_NAME="${DOTS_USER:-${SUDO_USER:-$(id -un)}}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_HOME="${USER_HOME:-/home/$USER_NAME}"

echo "creating backup direcotry at $USER_HOME"
mkdir -p "$USER_HOME/dots-backup"

echo "backup /etc/nixos"
if [ -e "$USER_HOME/dots-backup/nixos" ]; then
  echo "original /etc/nixos already backed up, keeping it"
else
  sudo cp -r /etc/nixos "$USER_HOME/dots-backup"
fi
echo "backup .config"
sudo rm -rf "$USER_HOME/dots-backup/.config"
sudo cp -r "$USER_HOME/.config" "$USER_HOME/dots-backup"
echo "backup .local"
sudo rm -rf "$USER_HOME/dots-backup/.local"
sudo cp -r "$USER_HOME/.local" "$USER_HOME/dots-backup"
echo "backup .icons"
sudo rm -rf "$USER_HOME/dots-backup/.icons"
sudo cp -r "$USER_HOME/.icons" "$USER_HOME/dots-backup"
sudo rm -rf /etc/nixos.bak
sudo mv /etc/nixos /etc/nixos.bak

echo "backup DONE!"
