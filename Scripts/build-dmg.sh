#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
source "$project_root/Release.env"
app_path="$project_root/Build/FreePdforall.app"
dmg_path="$project_root/PDF-Free-For-All-$VERSION.dmg"
package_root="$(mktemp -d /tmp/freepdforall-package.XXXXXX)"
stage_path="$package_root/content"
mount_path="$package_root/mount"
image_path="$package_root/release.dmg"
mounted=0
mkdir -p "$stage_path" "$mount_path"
cleanup() {
  if [[ "$mounted" == "1" ]]; then hdiutil detach "$mount_path" >/dev/null 2>&1 || true; fi
  rm -rf "$package_root"
}
trap cleanup EXIT

if [[ "${SKIP_APP_BUILD:-0}" != "1" ]]; then bash Scripts/build-app.sh; fi
package_app="$stage_path/PDF Free For All.app"
ditto --noqtn --noextattr --norsrc "$app_path" "$package_app"
codesign --verify --deep --strict "$package_app"
ln -s /Applications "$stage_path/Applications"
cat > "$stage_path/START HERE.txt" <<NOTES
PDF FREE FOR ALL $VERSION — build $BUILD_NUMBER

UNIVERSAL MAC APP — macOS 14 or later
Apple Silicon and Intel; no developer tools required on the receiving Mac.
For a guided installer, use PDF-Free-For-All-$VERSION-macOS-Universal.pkg.
Look for the blue handwritten PDF icon and the v$VERSION label on the home screen.

To preview without installing: open PDF Free For All.app in this disk image.
If an older copy is running, quit that copy first, preserving any unsaved document changes.
To install, drag PDF Free For All.app onto Applications. This build script does not install it.

Included: the redesigned All tools workspace; merge, split and extract; reorder,
rotate and delete pages; search, zoom and text highlighting; Word conversion;
handwritten signatures; PNG page export; printing. All implemented tools are free.

PDF to Word exports selectable text; complex Word formatting may change during import.
This local development release is ad-hoc signed and is not Apple-notarized.
NOTES
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" PACKAGE_APP="$package_app" python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
app=Path(os.environ['PACKAGE_APP'])
hash_file=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest={
    'name':'PDF FREE FOR ALL', 'version':os.environ['VERSION'], 'build':os.environ['BUILD_NUMBER'],
    'architectures':['arm64','x86_64'], 'minimum_macos':'14.0',
    'executable_sha256':hash_file(app/'Contents/MacOS/FreePdforall'),
    'icon_sha256':hash_file(app/'Contents/Resources/FreePdforall.icns'),
    'wordmark_sha256':hash_file(app/'Contents/Resources/FreePdforall-Wordmark.png')
}
(app.parent/'Release.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
hdiutil create -volname "PDF FREE FOR ALL $VERSION" -srcfolder "$stage_path" -format UDZO -imagekey zlib-level=9 "$image_path"
hdiutil verify "$image_path"
hdiutil attach -readonly -nobrowse -mountpoint "$mount_path" "$image_path"
mounted=1
mounted_app="$mount_path/PDF Free For All.app"
codesign --verify --deep --strict "$mounted_app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mounted_app/Contents/Info.plist")" = "$VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$mounted_app/Contents/Info.plist")" = "$BUILD_NUMBER"
cmp "$mounted_app/Contents/MacOS/FreePdforall" "$app_path/Contents/MacOS/FreePdforall"
cmp "$mounted_app/Contents/Resources/FreePdforall.icns" "$project_root/Assets/FreePdforall.icns"
cmp "$mounted_app/Contents/Resources/FreePdforall-Wordmark.png" "$project_root/Assets/FreePdforall-Wordmark.png"
test "$(readlink "$mount_path/Applications")" = "/Applications"
test -f "$mount_path/Release.json"
hdiutil detach "$mount_path"
mounted=0
mv -f "$image_path" "$dmg_path"
# Compatibility shortcut; the actual DMG lives directly in the project folder.
ln -sfn "../PDF-Free-For-All-$VERSION.dmg" "$project_root/Build/FreePdforall.dmg"
printf 'Version %s (build %s)\nActual DMG: %s\n' "$VERSION" "$BUILD_NUMBER" "$dmg_path" > "$project_root/Build/RELEASE.txt"
printf 'Created and verified complete release: %s\n' "$dmg_path"

shasum -a 256 "$(basename "$dmg_path")" > "$dmg_path.sha256"
