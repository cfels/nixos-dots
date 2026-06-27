#!/usr/bin/env bash

set -e

# vars
#VAR="something"

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
stow --dir=~/nixos-dots/Configs --target=~/.config --no-folding --adopt --restow config
stow --dir=~/nixos-dots/Configs --target=~ --no-folding --adopt --restow icons local walls
