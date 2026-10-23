# Project research and reuse record

Research checked on 22–23 October 2026. These projects informed feature scope and implementation choices. No source code, assets, branding, or copied layouts from them are included in the prototype.

| Project | Repository license checked | Useful ideas | Reuse decision |
| --- | --- | --- | --- |
| [Acroromi](https://github.com/romizone/acroromi) | Its README describes the project as MIT licensed. | Native SwiftUI/PDFKit foundation and a focused PDF toolkit. | Reference only; no code or brand assets reused. |
| [FolioFold](https://github.com/fmbabacan/FolioFold) | Apache-2.0, shown by GitHub. | Local-first Mac experience, safe exports, accessibility and an incremental roadmap. | Reference only; no code or brand assets reused. |
| [PDF Arranger](https://github.com/pdfarranger/pdfarranger) | GPL-3.0, shown by GitHub. | Clear page operations: merge, split, rotate, and rearrange. | Reference only; its GPL code is not incorporated. |
| [qpdf](https://github.com/qpdf/qpdf) | Apache-2.0, shown by GitHub. | Possible future low-level PDF transformations if PDFKit is insufficient. | Not bundled or linked in this prototype. Recheck qpdf's current license and NOTICE before adding it. |
| [PDF-Hub](https://github.com/Nishanth619/PDF-Hub) | Its repository LICENSE says proprietary and prohibits copying, modifying, or distributing. | Broad feature list can inform product scope. | No code, assets, or design copied; do not reuse without a separate written license. |

## Product direction

Keep the first release deliberately small: preview, organize, combine, split, sign, print, and export. Preserve original files and keep all processing local. The prototype includes a dependency-free native macOS DOCX import and text-first export experiment. Keep its fidelity limits visible; evaluate any future conversion engine for quality and redistribution terms before bundling it. Avoid implying that PDF-to-Word can preserve every layout perfectly.

## Interface research — 23 October 2026

| Source | Observed pattern | Application in this project |
| --- | --- | --- |
| [Apple Human Interface Guidelines: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) | macOS toolbars group navigation and document controls at the leading edge, common actions in the center, and search or secondary actions at the trailing edge. Commands should remain available through menus. | Group the document name, Read/Pages modes, conversion actions, signature, and save controls into one compact document bar. |
| [Apple Support: Use sidebars in Pages on Mac](https://support.apple.com/guide/pages/use-sidebars-tan0870f78aa/mac) | Page thumbnails in a sidebar support direct navigation and page reordering; document and formatting controls can live in a separate inspector. | Add a hideable page navigator and an optional quick-tools panel, while keeping the main PDF canvas central. |
| [Adobe Acrobat: Workspace basics](https://helpx.adobe.com/acrobat/desktop/get-started/learn-the-basics/workspace.html) | Acrobat separates Home, All tools, and Document views, with open documents organized in the document workspace. | Use a task chooser for the landing view and explicit Read and Pages modes after opening a PDF. |
| [Adobe Acrobat: Customize side panels](https://helpx.adobe.com/acrobat/desktop/get-started/preferences-and-settings/customize-side-panels.html) | Users can show or hide side panels to focus the workspace on the tools they use. | Add a small Panels menu for independent control of page thumbnails and quick actions. |
| [PDF Expert: Getting started](https://support.readdle.com/pdfexpert/en_US/annotate-pdfs/getting-started-with-pdf-expert) | Reader tools are grouped in the toolbar, with page navigation and thumbnails available from the document interface. | Keep the same broadly familiar organization pattern, but use our own palette, type hierarchy, labels, spacing, and artwork. |

These are references for common interaction patterns, not design templates. The refreshed screens use the project's deep teal, warm paper, and coral colors, an editorial serif home headline, and a project-drawn document illustration. No Adobe or PDF Expert code, text, assets, logo, or screen layout was reused. Adobe-specific trade dress and brand assets remain out of scope; this note records design intent, not legal advice.
