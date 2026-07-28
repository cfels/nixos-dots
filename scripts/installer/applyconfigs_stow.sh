#!/usr/bin/env bash

set -e

# delete and make dirs
#del dirs
rm -rf $HOME/.config
rm -rf $HOME/.local
rm -rf $HOME/.icons
#make dirs
mkdir $HOME/.config
mkdir $HOME/.local
mkdir $HOME/.icons

# stow
cd $HOME/nixos-dots/Configs/
stow config local walls

# symlnk /etc/nixos
rm -rf /etc/nixos
sudo ln -s /home/moxiu/nixos-dots/Configs/nixos /etc/nixos
