#!/usr/bin/env bash

USER_NAME="${DOTS_USER:-${SUDO_USER:-$(id -un)}}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_HOME="${USER_HOME:-/home/$USER_NAME}"

echo "remove shit"
sudo rm -rf /etc/nixos
sudo rm -rf "$USER_HOME/.config"
sudo rm -rf "$USER_HOME/.local"
sudo rm -rf "$USER_HOME/.icons"
echo "shit removed!"

echo "recreating directories"
mkdir -p "$USER_HOME/.config"
mkdir -p "$USER_HOME/.local"

echo "now restoring the stuff u backed up"

echo "restore /etc/nixos"
sudo cp -r "$USER_HOME/dots-backup/nixos" /etc/nixos
echo "restore .config"
sudo cp -r "$USER_HOME/dots-backup/.config/." "$USER_HOME/.config/"
echo "restore .local"
sudo cp -r "$USER_HOME/dots-backup/.local/." "$USER_HOME/.local/"
echo "restore .icons"
sudo cp -r "$USER_HOME/dots-backup/.icons/." "$USER_HOME/.icons/"
sudo chown -R "$USER_NAME" "$USER_HOME/.config" "$USER_HOME/.local" "$USER_HOME/.icons" 2>/dev/null || true
echo "resotre /etc/nixos from backup"
if [ -d /etc/nixos.bak ] && [ ! -L /etc/nixos.bak ]; then
  sudo rm -rf /etc/nixos
  sudo mv /etc/nixos.bak /etc/nixos
else
  sudo rm -rf /etc/nixos.bak
fi

echo "restore DONE!"
