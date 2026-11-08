#!/usr/bin/env bash
# usage: set-wallpaper.sh <image>  -> becomes the Firefox new-tab wallpaper
set -euo pipefail
src="${1:?usage: set-wallpaper.sh <image>}"
out="$(dirname "$0")/chrome/newtab-wallpaper.jpg"
python3 -I - "$src" "$out" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
im.thumbnail((2560, 1440))
im.save(sys.argv[2], quality=88)
print("wrote", sys.argv[2], im.size)
PY
# recolor Firefox from the new wallpaper (isolated config: desktop theming is untouched)
wallust run "$out" -C "$(dirname "$0")/wallust-ff.toml" --templates-dir "$(dirname "$0")/ff-templates" -s -n --no-hooks -q
echo "recolored: $(dirname "$0")/chrome/colors-ff.css"
# accent: wallpaper's own accent if it has color, else ice-blue fallback (gray/black-white images)
python3 -I - "$(dirname "$0")/chrome/colors-ff.css" <<'PY'
import re, sys, colorsys
p = sys.argv[1]
css = open(p).read()
cols = re.findall(r"--ff-c\d+:\s*(#[0-9A-Fa-f]{6})", css)
best, score = None, 0
for h in cols:
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (1, 3, 5))
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    if vv > 0.45 and ss * vv > score:
        best, score = (h, ss), ss * vv
accent = best[0] if best and best[1] >= 0.28 else "#9DBFE4"
css = re.sub(r"\n\s*--ff-accent:[^;]*;", "", css)
css = css.replace(":root {", ":root {\n  --ff-accent: %s;" % accent, 1)
open(p, "w").write(css)
print("accent:", accent)
PY
