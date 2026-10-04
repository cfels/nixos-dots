#!/usr/bin/env bash
set -euo pipefail

flake=/etc/nixos
flake_nix=$flake/flake.nix

version=$(nix eval --raw "$flake#nixosConfigurations.moxiu.pkgs.hyprland.version")
version_re=${version//./\\.}

line=$(curl -fsSL https://raw.githubusercontent.com/hyprnux/hyprglass/main/hyprpm.toml \
  | sed -n "s/.*\"[0-9a-f]\{40\}\",[[:space:]]*\"\([0-9a-f]\{40\}\)\".*# hyprland $version_re -> hyprglass v\([0-9.]*\).*/\1 \2/p" \
  | head -n1)

if [ -z "$line" ]; then
  echo "hyprglass: no upstream pin for hyprland $version yet; keeping current pin" >&2
  exit 0
fi

read -r pin hgver <<< "$line"
current=$(sed -n 's|.*github:hyprnux/hyprglass/\([0-9a-f]\{40\}\).*|\1|p' "$flake_nix" | head -n1)

if [ -z "$current" ]; then
  echo "hyprglass: flake.nix has no pinned revision; pin it by hand, then rerun" >&2
  exit 1
fi

if [ "$pin" = "$current" ]; then
  exit 0
fi

sed -i "s|github:hyprnux/hyprglass/$current|github:hyprnux/hyprglass/$pin|" "$flake_nix"
sed -i "/pluginName = \"hyprglass\";/,/version = /s/version = \"[^\"]*\";/version = \"$hgver\";/" "$flake_nix"
nix flake update --flake "$flake" hyprglass
echo "hyprglass: pinned to $pin ($hgver) for hyprland $version"
