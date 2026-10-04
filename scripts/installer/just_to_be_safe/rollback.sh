#!/usr/bin/env bash

echo "rollingback..."
sudo nixos-rebuild switch --flake "/etc/nixos#${DOTS_USER:-${SUDO_USER:-$(id -un)}}"
echo "rolled back"
