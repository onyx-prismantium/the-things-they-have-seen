#!/usr/bin/env bash
# Fetches the pinned NobodyWho Godot release (v9.4.0, per BUILD_BRIEF.md §2.2/§0.3)
# and installs the current platform's binary into addons/nobodywho/.
# The addon's binaries are gitignored (large per-platform blobs); this script is
# the reproducible install step. Config (.gdextension) and icon ARE tracked.
set -euo pipefail

VERSION="nobodywho-godot-v9.4.0"
REPO="nobodywho-ooo/nobodywho"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/addons/nobodywho"

os="$(uname -s)"
arch="$(uname -m)"
case "$os-$arch" in
  Linux-x86_64)   ASSET_MATCH="x86_64-unknown-linux-gnu-release.so" ;;
  Linux-aarch64)  ASSET_MATCH="aarch64-unknown-linux-gnu-release.so" ;;
  Darwin-x86_64)  ASSET_MATCH="x86_64-apple-darwin-release.dylib" ;;
  Darwin-arm64)   ASSET_MATCH="aarch64-apple-darwin-release.dylib" ;;
  *) echo "Unsupported platform: $os-$arch (see BUILD_BRIEF.md §2.2 for supported targets)"; exit 1 ;;
esac

mkdir -p "$DEST"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $VERSION ..."
gh release download "$VERSION" --repo "$REPO" --pattern "*.zip" -O "$tmp/nobodywho.zip"

echo "Extracting nobodywho.gdextension, icon.svg, and $ASSET_MATCH ..."
unzip -o -j "$tmp/nobodywho.zip" \
  "bin/addons/nobodywho/nobodywho.gdextension" \
  "bin/addons/nobodywho/icon.svg" \
  "bin/addons/nobodywho/libnobodywho-godot-$ASSET_MATCH" \
  -d "$DEST"

echo "Installed to $DEST"
ls -la "$DEST"
