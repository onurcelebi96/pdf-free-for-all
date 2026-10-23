#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_path="$project_root/Build/FreePdforall.app"
# Sign outside Desktop File Provider; it can attach FinderInfo during signing.
stage_path="$(mktemp -d /tmp/freepdforall-app.XXXXXX)"
trap 'rm -rf "$stage_path"' EXIT
app_path="$stage_path/FreePdforall.app"
contents_path="$app_path/Contents"
macos_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"

cd "$project_root"
source "$project_root/Release.env"
cat > "$project_root/Sources/FreePdforall/AppRelease.swift" <<SWIFT
// Generated from Release.env by Scripts/build-app.sh.
enum AppRelease {
    static let version = "$VERSION"
    static let build = "$BUILD_NUMBER"
}
SWIFT
bash Scripts/build-icon.sh
# Separate scratch roots keep development and distribution outputs independent.
for distribution_arch in arm64 x86_64; do
    swift build -c release --arch "$distribution_arch" --scratch-path "$project_root/.build/distribution-$distribution_arch"
done
mkdir -p "$macos_path" "$resources_path"
lipo -create \
    "$project_root/.build/distribution-arm64/arm64-apple-macosx/release/FreePdforall" \
    "$project_root/.build/distribution-x86_64/x86_64-apple-macosx/release/FreePdforall" \
    -output "$macos_path/FreePdforall"
lipo "$macos_path/FreePdforall" -verify_arch arm64 x86_64
# Remove SwiftPM's development-toolchain fallback paths before signing.
python3 - "$macos_path/FreePdforall" <<'PYTHON'
import re,subprocess,sys
binary=sys.argv[1]
commands=subprocess.check_output(['otool','-l','-arch','all',binary],text=True)
paths=set(re.findall(r'path (.+?) \(offset \d+\)',commands))
for path in paths:
    if path.startswith(('/Library/Developer/','/Applications/Xcode','/Users/')):
        subprocess.run(['install_name_tool','-delete_rpath',path,binary],check=True)
PYTHON

cp "$project_root/Assets/FreePdforall.icns" "$resources_path/FreePdforall.icns"
cp "$project_root/Assets/FreePdforall-Wordmark.png" "$resources_path/FreePdforall-Wordmark.png"
cp "$project_root/Assets/FreePdforall-Wordmark.svg" "$resources_path/FreePdforall-Wordmark.svg"
cp "$project_root/LICENSE" "$resources_path/LICENSE.txt"
cat > "$contents_path/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>FreePdforall</string>
    <key>CFBundleIdentifier</key><string>org.freepdforall.pdfdesk</string>
    <key>CFBundleName</key><string>PDF FREE FOR ALL</string>
    <key>CFBundleDisplayName</key><string>PDF FREE FOR ALL</string>
    <key>CFBundleIconFile</key><string>FreePdforall.icns</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
xattr -cr "$app_path"
xattr -d com.apple.FinderInfo "$app_path" 2>/dev/null || true
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app_path"
else
    if [[ "${REQUIRE_DISTRIBUTION_SIGNING:-0}" == "1" ]]; then
        echo "A Developer ID Application certificate is required for public distribution." >&2
        exit 1
    fi
    codesign --force --options runtime --sign - "$app_path"
fi
# Verify the signed bundle before copying it to the Desktop.
xattr -d com.apple.FinderInfo "$app_path" 2>/dev/null || true
codesign --verify --deep --strict "$app_path"
ditto --noqtn --noextattr --norsrc "$app_path" "$output_path"
xattr -d com.apple.FinderInfo "$output_path" 2>/dev/null || true
echo "Created: $output_path"
