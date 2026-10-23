#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
source Release.env
if [[ "${REQUIRE_DISTRIBUTION_SIGNING:-0}" == "1" ]]; then
    : "${DEVELOPER_ID_APPLICATION:?Set a Developer ID Application identity}"
    : "${DEVELOPER_ID_INSTALLER:?Set a Developer ID Installer identity}"
fi
stage="$(mktemp -d /tmp/freepdforall-installer.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
if [[ "${SKIP_APP_BUILD:-0}" != "1" ]]; then bash Scripts/build-app.sh; fi
app="$project_root/Build/FreePdforall.app"
lipo "$app/Contents/MacOS/FreePdforall" -verify_arch arm64 x86_64
mkdir -p "$stage/payload/Applications"
ditto --noqtn --noextattr --norsrc "$app" "$stage/payload/Applications/PDF Free For All.app"
codesign --verify --deep --strict "$stage/payload/Applications/PDF Free For All.app"
xattr -cr "$stage/payload"
COPYFILE_DISABLE=1 pkgbuild --analyze --root "$stage/payload" "$stage/components.plist"
python3 - "$stage/components.plist" <<'PY'
import plistlib,sys
p=sys.argv[1]
with open(p,'rb') as f: rows=plistlib.load(f)
for r in rows:
    r['BundleIsRelocatable']=False
    r['BundleIsVersionChecked']=True
    r['BundleHasStrictIdentifier']=True
    r['BundleOverwriteAction']='upgrade'
with open(p,'wb') as f: plistlib.dump(rows,f)
PY
COPYFILE_DISABLE=1 pkgbuild --root "$stage/payload" --component-plist "$stage/components.plist" --install-location / \
    --identifier org.freepdforall.pdfdesk.installer --version "$VERSION" "$stage/FreePdforall-component.pkg"
cat > "$stage/Distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>PDF FREE FOR ALL $VERSION</title>
  <welcome file="Welcome.html" mime-type="text/html"/>
  <readme file="ReadMe.html" mime-type="text/html"/>
  <conclusion file="Conclusion.html" mime-type="text/html"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <volume-check script="true"><allowed-os-versions><os-version min="14.0"/></allowed-os-versions></volume-check>
  <choices-outline><line choice="app"/></choices-outline>
  <choice id="app" title="PDF FREE FOR ALL" visible="false"><pkg-ref id="org.freepdforall.pdfdesk.installer"/></choice>
  <pkg-ref id="org.freepdforall.pdfdesk.installer" version="$VERSION" onConclusion="None">FreePdforall-component.pkg</pkg-ref>
  <pkg-ref id="org.freepdforall.pdfdesk.installer"><must-close><app id="org.freepdforall.pdfdesk"/></must-close></pkg-ref>
</installer-gui-script>
XML
if [[ -n "${DEVELOPER_ID_INSTALLER:-}" ]]; then
    productbuild --distribution "$stage/Distribution.xml" --resources "$project_root/InstallerAssets" \
        --package-path "$stage" --sign "$DEVELOPER_ID_INSTALLER" --timestamp "$stage/release.pkg"
else
    productbuild --distribution "$stage/Distribution.xml" --resources "$project_root/InstallerAssets" \
        --package-path "$stage" "$stage/release.pkg"
fi
# Inspect actual packaged files, without installing anything on this Mac.
pkgutil --expand-full "$stage/release.pkg" "$stage/expanded"
packaged_app="$stage/expanded/FreePdforall-component.pkg/Payload/Applications/PDF Free For All.app"
codesign --verify --deep --strict "$packaged_app"
lipo "$packaged_app/Contents/MacOS/FreePdforall" -verify_arch arm64 x86_64
cmp "$packaged_app/Contents/MacOS/FreePdforall" "$app/Contents/MacOS/FreePdforall"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$packaged_app/Contents/Info.plist")" = "$VERSION"
installer -pkg "$stage/release.pkg" -target / -showChoicesXML > "$stage/choices.xml"
output="$project_root/PDF-Free-For-All-$VERSION-macOS-Universal.pkg"
mv -f "$stage/release.pkg" "$output"
shasum -a 256 "$(basename "$output")" > "$output.sha256"
ln -sfn "../$(basename "$output")" "$project_root/Build/FreePdforall.pkg"
mkdir -p "$project_root/QA/Distribution-$VERSION"
cp "$stage/Distribution.xml" "$stage/choices.xml" "$stage/components.plist" "$project_root/QA/Distribution-$VERSION/"
pkgutil --payload-files "$output" > "$project_root/QA/Distribution-$VERSION/payload-files.txt"
printf 'Created universal installer (not installed): %s\n' "$output"
