#!/usr/bin/env bash
# picks the next image in wallpapers/ and applies it (Firefox new tab + Firefox colors only)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mapfile -t imgs < <(find "$here/wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) | sort)
[ "${#imgs[@]}" -gt 0 ] || exit 0
idx_file="$here/.rotate-index"
idx=$(( ( $(cat "$idx_file" 2>/dev/null || echo -1) + 1 ) % ${#imgs[@]} ))
echo "$idx" > "$idx_file"
"$here/set-wallpaper.sh" "${imgs[$idx]}"
