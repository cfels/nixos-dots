#!/usr/bin/env bash
set -euo pipefail

flake=${1:-/etc/nixos}
flake_nix=$flake/flake.nix
hyprglass_nix=$flake/packages/hyprglass.nix

repository=https://github.com/hyprnux/hyprglass
release_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$repository/releases/latest")
tag=${release_url##*/}

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "hyprglass: invalid release tag: $tag" >&2
  exit 1
fi

refs=$(git ls-remote --tags --exit-code "$repository.git" "refs/tags/$tag" "refs/tags/$tag^{}")
pin=''
while read -r revision ref; do
  # Annotated tags have a separate tag object; pin the commit they point to.
  if [[ "$ref" == "refs/tags/$tag^{}" ]]; then
    pin=$revision
    break
  fi
  if [[ "$ref" == "refs/tags/$tag" ]]; then
    pin=$revision
  fi
done <<<"$refs"

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
