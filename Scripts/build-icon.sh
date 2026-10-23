#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
asset_root="$project_root/Assets"
iconset="$asset_root/AppIcon.iconset"

mkdir -p "$iconset"
swift "$project_root/Scripts/render-branding.swift" "$project_root"

while read -r height width name; do
  sips -z "$height" "$width" "$asset_root/FreePdforall-AppIcon-1024.png" --out "$iconset/$name" >/dev/null
done <<'SIZES'
16 16 icon_16x16.png
32 32 icon_16x16@2x.png
32 32 icon_32x32.png
64 64 icon_32x32@2x.png
128 128 icon_128x128.png
256 256 icon_128x128@2x.png
256 256 icon_256x256.png
512 512 icon_256x256@2x.png
512 512 icon_512x512.png
1024 1024 icon_512x512@2x.png
SIZES

iconutil -c icns "$iconset" -o "$asset_root/FreePdforall.icns"
echo "Built original PDF FREE FOR ALL wordmark and macOS app icon."
