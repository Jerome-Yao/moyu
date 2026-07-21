#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output="$repo_root/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

magick -size 1024x1024 xc:'#FAF4E8' \
  -fill none -stroke '#DDD5C9' -strokewidth 74 \
  -draw 'circle 512,512 798,512' \
  -stroke '#F04F1F' -strokewidth 74 \
  -draw 'arc 226,226 798,798 135,405' \
  -stroke '#181614' -strokewidth 54 \
  -draw 'line 512,512 512,316' \
  -fill '#181614' -stroke none \
  -draw 'circle 512,316 539,316' \
  -draw 'circle 512,512 566,512' \
  -stroke '#F04F1F' -strokewidth 54 \
  -draw 'line 512,512 677,415' \
  -fill '#F04F1F' -stroke none \
  -draw 'circle 677,415 704,415' \
  -fill '#181614' \
  -draw 'circle 310,714 334,714' \
  -alpha off "$output"

identify -format '%wx%h %[channels]\n' "$output"
