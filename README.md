# PDF FREE FOR ALL

Free PDF tools for macOS, built with SwiftUI and PDFKit. Designed by Onur Celebi.

![PDF FREE FOR ALL](Assets/FreePdforall-Wordmark.svg)

## Download the preview

Installer downloads are being prepared. Source code is available now; a v0.6.0 preview release is saved as a draft and has not been published.

The planned release contains a guided `.pkg` installer, an optional `.dmg`, and a ZIP containing the installer. GitHub source-code archives are for developers. Artwork PNGs and the macOS icon are generated locally by the build scripts.

**Distribution status:** this preview has an ad-hoc signed app, an unsigned installer, and no Apple notarization. Gatekeeper rejected the installer during assessment with “no usable signature.” An internet-downloaded copy may be blocked. Do not disable macOS security protections. Developer ID signing, notarization, and testing on other Macs remain incomplete.

## Features

- Open multiple PDFs in tabs; each keeps its own edits, undo history and viewport.
- Merge PDFs; split and extract pages; reorder, rotate and delete pages.
- Search selectable text, zoom, and export a page as PNG.
- Persistent yellow and green highlighting with grouped undo.
- Draw a handwritten signature and place it on a PDF. This is an ink annotation, not a certificate-based digital signature.
- Local DOCX-to-PDF and text-first PDF-to-DOCX conversion.
- Print using the native macOS dialog and save separate copies that protect original inputs.

Documents are handled locally. The app has no account, subscription, analytics client or remote document-processing service.

## Compatibility

The universal app contains **arm64 and x86_64** executables targeting **macOS 14 or later**. The receiving Mac does not need Xcode, Python, Microsoft Word or this source folder. Intel hardware and the full macOS version matrix have not been physically tested. A clean macOS VM test could not be completed because the development Mac lacked sufficient disk space. macOS 13 and earlier, iPadOS and Windows are not supported.

## Build from source

Use macOS 14+ with a compatible Swift toolchain (the package uses Swift tools 5.9). Run these commands from the repository root:

```sh
swift run
```

To run the core regression suite, use a toolchain with Swift Testing:

```sh
bash Scripts/test.sh
```

To build the universal app and installer:

```sh
bash Scripts/build-installer.sh
```

To create the optional disk image:

```sh
bash Scripts/build-dmg.sh
```

The scripts create artifacts locally. They do not install into Applications or upload to Apple. `Scripts/notarize-installer.sh` is an optional future step requiring the owner's Developer ID certificates and Keychain credentials. See [DISTRIBUTION.md](DISTRIBUTION.md).

## Verification and limits

The feature source preceding this packaging release passed 90 automated checks: 14 core checks, 61 feature/model checks and 15 tab checks. The local review also covered native save/print dialogs, highlighting, tab switching and package expansion. This does not establish reliability for every PDF or device.

PDF-to-Word exports selectable text and does not reconstruct images, tables, columns or page design. OCR and crash recovery are not implemented. Complex Word layouts may change during import. Seven of eight generated PDF samples produced qpdf zero-offset-object warnings, although PDFKit reopening and independent Poppler rendering succeeded. Broader compatibility testing remains necessary.

## License and references

Original project source is released under the [MIT License](LICENSE). Apple frameworks remain subject to Apple's terms. Third-party apps informed feature research only; their code, branding and assets were not copied. See [RESEARCH.md](RESEARCH.md).

Public PDF fixtures used during local testing are not redistributed in this repository or app release.
