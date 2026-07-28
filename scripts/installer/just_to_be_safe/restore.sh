#!/usr/bin/env bash

echo "remove shit"
sudo rm -rf /etc/nixos
rm -rf $HOME/.config
rm -rf $HOME/.local
echo "shit removed!"

echo "recreating directories"
mkdir $HOME/.config
mkdir $HOME/.local

echo "now restoring the stuff u backed up"

echo "restore /etc/nixos"
sudo cp -r $HOME/dots-backup/nixos /etc/nixos
echo "restore .config"
sudo cp -r $HOME/dots-backup/.config $HOME/.config
echo "restore .local"
sudo cp -r $HOME/dots-backup/.local $HOME/.local
echo "resotre /etc/nixos from backup"
sudo mv /etc/nixos.bak /etc/nixos

echo "restore DONE!"
