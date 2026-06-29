#!/usr/bin/env bash

set -e

echo "copy profile"
cp -r $HOME/nixos-dots/Configs/lb_profile/profile/* $HOME/.config/librewolf/librewolf/*.default/
echo "done! (this solution maybe works)"
