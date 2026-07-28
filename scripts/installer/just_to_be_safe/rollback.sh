#!/usr/bin/env bash

echo "rollingback..."
doas nixos-rebuild switch --flake /etc/nixos#moxiu
echo "rolled back"
