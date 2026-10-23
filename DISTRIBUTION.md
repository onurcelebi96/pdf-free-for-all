# macOS distribution

## Artifacts

- `PDF-Free-For-All-0.6.0-macOS-Universal.pkg`: standard macOS Installer, placing the self-contained app in `/Applications/PDF Free For All.app`.
- `PDF-Free-For-All-0.6.0.dmg`: optional drag-and-drop installation, using the same universal app.
- Corresponding `.sha256` files permit comparison after transfer.

Target: macOS 14 and later; arm64 (Apple Silicon) and x86_64 (Intel). This is macOS software; no Windows executable is included. Version targeting is distinct from hardware/OS runtime verification: only the current Apple Silicon Mac has been exercised. A real macOS 14 Mac and Intel Mac are still needed for the distribution matrix.

The package contains the executable, app icons/wordmark, Info.plist and original MIT license. Its runtime dependencies are Apple system frameworks/libraries. Developer tooling and the source project are not required on the receiving Mac. The app has no account, remote document service, post-install download or external Word converter dependency.

## Build

`./Scripts/build-installer.sh` builds both CPU slices in separate SwiftPM scratch roots, combines them with lipo, signs the app, builds the component and product package, expands the final product and verifies the actual payload. No installation is performed by the script.

`./Scripts/build-dmg.sh` builds a universal app and creates the optional disk image. Package creation is local and does not publish anything online.

The installer specifies a macOS 14 minimum, uses only the local system domain, disables bundle relocation, requires the existing app to close, uses version checks and upgrades only its application bundle. It has no pre/post-install scripts, daemons, kernel extensions, default-app changes or automatic restart. Test data and developer tools are excluded.

## Apple signing status

No valid code signing identity was found on this Mac. The owner does not currently have an Apple Developer Program membership. The generated app uses an ad-hoc signature; the installer is unsigned and is not notarized. Building a PKG alone does not make Gatekeeper trust an internet download. This is a transferable local preview, not a completed Apple-verified public release. Security bypasses are not part of installation.

To complete a public release later:

1. Obtain Developer ID Application and Developer ID Installer certificates in Keychain on the release Mac through the owner's Apple Developer account.
2. Set `DEVELOPER_ID_APPLICATION`, `DEVELOPER_ID_INSTALLER` and `REQUIRE_DISTRIBUTION_SIGNING=1` for the build. Values identify Keychain certificates; do not place private keys or account passwords in the project.
3. Replace the preview signing-status wording in InstallerAssets/ReadMe.html with accurate release wording before rebuilding. Signing is not notarization; avoid claiming approval until Apple accepts it.
4. Build the installer. Set up a notarytool Keychain profile interactively using Apple's workflow; no credentials belong in repository files.
5. Set `NOTARY_PROFILE` to that profile name and run `./Scripts/notarize-installer.sh`. This explicitly submits the signed installer to Apple. The script requires acceptance, staples and validates the ticket, assesses the package, and refreshes its checksum. It refuses unsigned packages.
6. Verify an actual browser-downloaded, quarantined copy on a separate compatible Mac. Publish only after that check. If distributing the DMG too, sign/notarize/staple that artifact separately.

Apple references: [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [Installer distribution XML](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html).

## No upload or local installation

No website upload, Apple notarization request, account enrollment, or `/Applications` installation is performed during this preparation. The local build remains inside `FreePdforall project`.
