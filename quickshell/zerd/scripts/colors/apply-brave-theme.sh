#!/usr/bin/env bash
# Generates a Brave/Chromium theme extension from the current wallust palette.
# Loaded via --load-extension in brave-flags.conf, so Brave picks it up on next launch.
# Chromium themes only take effect on browser restart - there's no live-reload API.

set -euo pipefail

WALLUST_COLORS="$HOME/.cache/wallust/colors.json"
THEME_DIR="$HOME/.local/state/brave-wallust-theme"

command -v jq >/dev/null 2>&1 || exit 0
[[ -f "$WALLUST_COLORS" ]] || exit 0

mkdir -p "$THEME_DIR"

hex_to_rgb_array() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo "[$r, $g, $b]"
}

adjust_hex() {
    local hex="${1#\#}"
    local amount="$2"
    local r=$((16#${hex:0:2} + amount))
    local g=$((16#${hex:2:2} + amount))
    local b=$((16#${hex:4:2} + amount))
    ((r < 0)) && r=0; ((r > 255)) && r=255
    ((g < 0)) && g=0; ((g > 255)) && g=255
    ((b < 0)) && b=0; ((b > 255)) && b=255
    printf "#%02x%02x%02x" "$r" "$g" "$b"
}

BG=$(jq -r '.special.background' "$WALLUST_COLORS")
FG=$(jq -r '.special.foreground' "$WALLUST_COLORS")
ACCENT=$(jq -r '.colors.color4' "$WALLUST_COLORS")

TOOLBAR=$(adjust_hex "$BG" 12)
FRAME_INACTIVE=$(adjust_hex "$BG" -6)

cat > "$THEME_DIR/manifest.json" << EOF
{
  "manifest_version": 3,
  "name": "zerda-shell wallust theme",
  "description": "Auto-generated from the current wallpaper palette. Do not install manually.",
  "version": "1.0",
  "theme": {
    "colors": {
      "frame": $(hex_to_rgb_array "$BG"),
      "frame_inactive": $(hex_to_rgb_array "$FRAME_INACTIVE"),
      "toolbar": $(hex_to_rgb_array "$TOOLBAR"),
      "toolbar_text": $(hex_to_rgb_array "$FG"),
      "toolbar_button_icon": $(hex_to_rgb_array "$ACCENT"),
      "tab_text": $(hex_to_rgb_array "$FG"),
      "tab_background_text": $(hex_to_rgb_array "$FG"),
      "bookmark_text": $(hex_to_rgb_array "$FG"),
      "ntp_background": $(hex_to_rgb_array "$BG"),
      "ntp_text": $(hex_to_rgb_array "$FG"),
      "ntp_link": $(hex_to_rgb_array "$ACCENT"),
      "button_background": $(hex_to_rgb_array "$ACCENT")
    },
    "properties": {
      "ntp_background_alignment": "bottom"
    }
  }
}
EOF
