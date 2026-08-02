#!/usr/bin/env bash

set -e

# delete and make dirs
#del dirs
sudo rm -rf "$HOME/.config"
sudo rm -rf "$HOME/.icons"
#make dirs
mkdir -p $HOME/.config
mkdir -p $HOME/.icons

# install stow
#nix-shell -p stow git wget aria2

# stow
cd $HOME/nixos-dots/Configs/
stow config local walls

# symlnk /etc/nixos
rm -rf /etc/nixos
sudo ln -s /home/moxiu/nixos-dots/Configs/nixos /etc/nixos
cp $HOME/dots-backup/nixos/hardware-configuration.nix /etc/nixos
sudo git config --global --add safe.directory /home/moxiu/nixos-dots
sudo cp -r $HOME/nixos-dots/Configs/config/.config/nvim/ /root/.config/
fc-cache -f -v
sudo nixos-rebuild switch --flake /etc/nixos#moxiu
