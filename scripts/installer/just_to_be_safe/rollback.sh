#!/usr/bin/env bash

echo "rollingback..."
sudo nixos-rebuild switch --rollback
echo "rolled back"
