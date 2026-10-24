#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ]; then
  echo 'This script requires macOS and a completed flutter build macos --release.' >&2
  exit 1
fi

app=build/macos/Build/Products/Release/ClipShelf.app
test -d "$app"
binary="$app/Contents/MacOS/ClipShelf"
# Do not label a single-architecture binary as universal.
lipo -verify_arch arm64 x86_64 "$binary"

output=dist/macos
mkdir -p "$output"
staging=$(mktemp -d "${TMPDIR:-/tmp}/clipshelf-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/ClipShelf.app"
# Local ad-hoc signing checks integrity without requiring a developer identity.
codesign --force --deep --sign - "$staging/ClipShelf.app"
codesign --verify --deep --strict --verbose=2 "$staging/ClipShelf.app"
ditto -c -k --sequesterRsrc --keepParent "$staging/ClipShelf.app" "$output/ClipShelf-macOS-universal.zip"
ln -s /Applications "$staging/Applications"
hdiutil create -volname ClipShelf -srcfolder "$staging" -ov -format UDZO "$output/ClipShelf-macOS-universal.dmg"
cat > "$output/README.txt" <<'NOTICE'
ClipShelf for macOS 12 or newer (Apple Silicon and Intel).

Open the DMG and drag ClipShelf into Applications, or extract the ZIP.
This test build is ad-hoc signed, not Developer ID signed or notarized.
macOS may require an explicit approval in System Settings > Privacy & Security
after the first launch attempt. Approve it only if you trust this build's source.

Clipboard history is stored locally. The old clips.json file is left unchanged.
NOTICE
shasum -a 256 "$output/ClipShelf-macOS-universal.zip" "$output/ClipShelf-macOS-universal.dmg" > "$output/SHA256SUMS"
