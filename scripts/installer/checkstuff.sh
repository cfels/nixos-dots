#!/usr/bin/env bash

set -e

if ! grep -q '^ID=nixos' /etc/os-release 2>/dev/null; then
  echo "wrong os"
  exit 1
fi
echo "alr ur on nixos"

ls -la ~/.config
ls -la ~/.local 2>/dev/null || true
sudo ls -la /etc/nixos 2>/dev/null || true
