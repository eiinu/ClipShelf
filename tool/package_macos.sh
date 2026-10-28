#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ]; then
  echo 'This script requires macOS and a completed universal flutter build macos --release.' >&2
  exit 1
fi

app=build/macos/Build/Products/Release/ClipShelf.app
test -d "$app"
lipo "$app/Contents/MacOS/ClipShelf" -verify_arch arm64 x86_64

if [ "$#" -eq 0 ]; then set -- arm64 x86_64; fi
for arch in "$@"; do
  case "$arch" in
    arm64|x86_64) ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
done

staging=$(mktemp -d "${TMPDIR:-/tmp}/clipshelf-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT

# Thin every embedded Mach-O, including Flutter, Dart AOT and native plugins.
# Thinning only the main executable leaves most of a Flutter app universal.
thin_app() {
  local bundle=$1 arch=$2 file architectures temporary mode
  while IFS= read -r -d '' file; do
    case "$(file -b "$file")" in
      *Mach-O*) ;;
      *) continue ;;
    esac
    architectures=$(lipo "$file" -archs)
    case " $architectures " in
      *" $arch "*) ;;
      *) echo "Missing $arch in $file ($architectures)" >&2; return 1 ;;
    esac
    if [ "$architectures" != "$arch" ]; then
      mode=$(stat -f '%Lp' "$file")
      temporary=$(mktemp "${file}.thin.XXXXXX")
      lipo "$file" -thin "$arch" -output "$temporary"
      chmod "$mode" "$temporary"
      mv -f "$temporary" "$file"
    fi
  done < <(find "$bundle" -type f -print0)
}

verify_app() {
  local bundle=$1 arch=$2 file architectures
  while IFS= read -r -d '' file; do
    case "$(file -b "$file")" in
      *Mach-O*) ;;
      *) continue ;;
    esac
    architectures=$(lipo "$file" -archs)
    if [ "$architectures" != "$arch" ]; then
      echo "Unexpected architectures in $file: $architectures (expected $arch only)" >&2
      return 1
    fi
  done < <(find "$bundle" -type f -print0)
  codesign --verify --deep --strict --verbose=2 "$bundle"
}

for arch in "$@"; do
  output="dist/macos/$arch"
  root="$staging/$arch"
  mkdir -p "$output" "$root"
  ditto "$app" "$root/ClipShelf.app"
  thin_app "$root/ClipShelf.app" "$arch"
  # Thinning changes signed binaries; sign only after all slices are removed.
  codesign --force --deep --sign - "$root/ClipShelf.app"
  verify_app "$root/ClipShelf.app" "$arch"
  ln -s /Applications "$root/Applications"
  name="ClipShelf-macOS-$arch"
  hdiutil create -volname ClipShelf -srcfolder "$root" -ov -format UDZO "$output/$name.dmg"
  hdiutil verify "$output/$name.dmg"
  cat > "$output/README.txt" <<NOTICE
ClipShelf for macOS 12 or newer. Architecture: $arch.
arm64: Apple Silicon (M-series). x86_64: Intel.

Open the DMG and drag ClipShelf into Applications.
This test build is ad-hoc signed, not Developer ID signed or notarized.
macOS may require an explicit approval in System Settings > Privacy & Security
following the first launch attempt. Approve only if you trust this build's source.

Clipboard history stays local. The old clips.json file remains unchanged.
NOTICE
  (cd "$output"; shasum -a 256 "$name.dmg" > SHA256SUMS)
  app_kib=$(du -sk "$root/ClipShelf.app" | awk '{print $1}')
  dmg_bytes=$(stat -f '%z' "$output/$name.dmg")
  echo "$arch: app=${app_kib} KiB; DMG=${dmg_bytes} bytes"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "- $arch: installed app ${app_kib} KiB; DMG ${dmg_bytes} bytes. Every Mach-O verified as $arch only; signature and DMG checks passed." >> "$GITHUB_STEP_SUMMARY"
  fi
done
