#!/usr/bin/env bash

echo "creating backup direcotry at $HOME"
mkdir $HOME/dots-backup

echo "backup /etc/nixos"
sudo cp -r /etc/nixos $HOME/dots-backup
echo "backup .config"
sudo cp -r $HOME/.config $HOME/dots-backup
echo "backup .local"
sudo cp -r $HOME/.local $HOME/dots-backup
echo "backup .icons"
sudo cp -r $HOME/.icons $HOME/dots-backup

echo "backup DONE!"
