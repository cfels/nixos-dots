#!/usr/bin/env bash
set -euo pipefail

flake=${1:-/etc/nixos}
flake_nix=$flake/flake.nix
hyprglass_nix=$flake/packages/hyprglass.nix

api=https://api.github.com/repos/hyprnux/hyprglass
tag=$(curl -fsSL "$api/releases/latest" | jq -er '.tag_name | select(type == "string")')

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "hyprglass: invalid release tag: $tag" >&2
  exit 1
fi

pin=$(curl -fsSL "$api/commits/$tag" | jq -er '.sha | select(type == "string")')
if [[ ! "$pin" =~ ^[0-9a-f]{40}$ ]]; then
  echo "hyprglass: invalid commit for $tag: $pin" >&2
  exit 1
fi

hgver=${tag#v}
current=$(sed -n 's|.*github:hyprnux/hyprglass/\([0-9a-f]\{40\}\).*|\1|p' "$flake_nix" | head -n1)

if [ -z "$current" ]; then
  echo "hyprglass: flake.nix has no pinned revision; pin it by hand, then rerun" >&2
  exit 1
fi

sed -i "s|github:hyprnux/hyprglass/$current|github:hyprnux/hyprglass/$pin|" "$flake_nix"
sed -i "/pluginName = \"hyprglass\";/,/version = /s/version = \"[^\"]*\";/version = \"$hgver\";/" "$hyprglass_nix"
# Refresh even an unchanged pin so a previously interrupted update can recover.
nix flake update --flake "$flake" hyprglass
echo "hyprglass: pinned latest release $tag ($pin)"
