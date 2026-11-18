#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(cd "$repo_root" && node -p 'require("./package.json").version')"
architecture="$(uname -m)"
runtime_root="$repo_root/build/electron-runtime"
package_root="$repo_root/build/macos-package-root"
package_path="$repo_root/dist/Halkhata-macos-${architecture}.pkg"
dmg_path="$repo_root/dist/Halkhata-macos-${architecture}.dmg"
runtime_version="$(cat "$runtime_root/r-framework-version")"
runtime_source="$runtime_root/mac-r-framework/Library/Frameworks/R.framework/Versions/$runtime_version"
app_source="$(find "$repo_root/dist" -maxdepth 3 -type d -name 'Halkhata.app' -print -quit)"

if [[ -z "$app_source" || ! -d "$runtime_source" ]]; then
  echo "The packaged app or bundled R framework is missing." >&2
  exit 1
fi

if [[ -e "$package_root" ]]; then
  rm -r "$package_root"
fi
mkdir -p "$package_root/Applications" \
  "$package_root/Library/Frameworks/R.framework/Versions"
ditto "$app_source" "$package_root/Applications/Halkhata.app"
ditto "$runtime_source" \
  "$package_root/Library/Frameworks/R.framework/Versions/$runtime_version"
mkdir -p "$repo_root/dist"

pkgbuild \
  --root "$package_root" \
  --identifier "com.halkhata.desktop" \
  --version "$version" \
  --install-location / \
  "$package_path"
hdiutil create \
  -volname "Halkhata Installer" \
  -srcfolder "$package_path" \
  -ov \
  -format UDZO \
  "$dmg_path"
