#!/bin/bash
# Optional final step once a Developer ID account/certificates have been configured.
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
source Release.env
: "${NOTARY_PROFILE:?Set the name of a notarytool Keychain credential profile; never put a password in this script}"
installer_path="$project_root/PDF-Free-For-All-$VERSION-macOS-Universal.pkg"
# Refuse ad-hoc/unsigned builds instead of reporting a public release prematurely.
notary_stage="$(mktemp -d /tmp/freepdforall-notary.XXXXXX)"
trap 'rm -rf "$notary_stage"' EXIT
pkgutil --expand-full "$installer_path" "$notary_stage/expanded"
packaged_app="$notary_stage/expanded/FreePdforall-component.pkg/Payload/Applications/PDF Free For All.app"
codesign --verify --deep --strict "$packaged_app"
codesign -dv "$packaged_app" 2>&1 | rg '^Authority=Developer ID Application:' >/dev/null
pkgutil --check-signature "$installer_path" | rg 'Developer ID Installer:' >/dev/null
qa="$project_root/QA/Distribution-$VERSION"
mkdir -p "$qa"
xcrun notarytool submit "$installer_path" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$qa/notary-result.json"
python3 - "$qa/notary-result.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple has not accepted this installer; inspect the notarization log before publishing.')
PY
xcrun stapler staple "$installer_path"
xcrun stapler validate "$installer_path"
spctl --assess --type install --verbose=2 "$installer_path"
shasum -a 256 "$(basename "$installer_path")" > "$installer_path.sha256"
echo "Apple notarization accepted and ticket stapled."
