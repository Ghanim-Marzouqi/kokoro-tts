#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo_root="$(cd .. && pwd)"
app_name="KokoroBar"
dist_dir="$PWD/dist"
app_dir="$dist_dir/$app_name.app"
contents_dir="$app_dir/Contents"

swift build -c release

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

cp ".build/release/$app_name" "$contents_dir/MacOS/$app_name"
cp "Resources/Info.plist" "$contents_dir/Info.plist"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude 'cache/*.wav' \
    "$repo_root/backend/" "$contents_dir/Resources/backend/"
else
  mkdir -p "$contents_dir/Resources/backend"
  ditto "$repo_root/backend" "$contents_dir/Resources/backend"
fi

chmod +x "$contents_dir/Resources/backend/scripts/"*.sh

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$app_dir"
fi

echo "Built $app_dir"
echo "You can move it to /Applications for personal use."
