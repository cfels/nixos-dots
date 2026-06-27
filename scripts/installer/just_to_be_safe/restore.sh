#!/usr/bin/env bash

echo "remove shit"
sudo rm -rf /etc/nixos
rm -rf $HOME/.config
rm -rf $HOME/.local
rm -rf $HOME/.icons
echo "shit removed!"

echo "recreating directories"
sudo mkdir /etc/nixos
mkdir $HOME/.config
mkdir $HOME/.local
mkdir $HOME/.icons

echo "now restoring the stuff u backed up"

echo "restore /etc/nixos"
sudo cp -r $HOME/dots-backup/nixos /etc/nixos
echo "restore .config"
sudo cp -r $HOME/dots-backup/.config $HOME/.config
echo "restore .local"
sudo cp -r $HOME/dots-backup/.local $HOME/.local
echo "resotre .icons"
sudo cp -r $HOME/dots-backup/.icons $HOME/.icons

echo "restore DONE!"
