#!/usr/bin/env python3
"""Moves the theme-folder wallpapers (Nord/Dark/x.png ...) into Colours/<colour>/ as <theme>-x.png.
   wallpaper-sort.py [--apply|--undo]   (no flag = dry run). Manifest: ~/.local/state/zerd-wallpaper-sort.json"""
import os, sys, json, shutil, colorsys, re
from PIL import Image
root = os.path.expanduser("~/Pictures/Wallpapers")
man = os.path.expanduser("~/.local/state/zerd-wallpaper-sort.json")
EXT = (".png", ".jpg", ".jpeg", ".webp")

def undo():
    m = json.load(open(man))
    for new, old in m.items():
        if os.path.exists(new):
            os.makedirs(os.path.dirname(old), exist_ok=True); shutil.move(new, old)
    os.remove(man); print("restored", len(m))

def folder(path):
    im = Image.open(path)
    try: im.draft("RGB", (128, 128))
    except Exception: pass
    im = im.convert("RGB").resize((32, 32))
    px = list(im.getdata())
    light = sum(0.299*r + 0.587*g + 0.114*b for r, g, b in px) / len(px) / 255
    hs = [colorsys.rgb_to_hsv(r/255, g/255, b/255) for r, g, b in px]
    col = [h for h in hs if h[1] >= 0.18 and h[2] >= 0.12]
    if len(col) < len(px) * 0.25:
        return "Dark" if light < 0.45 else "Light"
    # circular mean hue, weighted by saturation
    import math
    x = sum(math.cos(h[0]*2*math.pi) * h[1] for h in col); y = sum(math.sin(h[0]*2*math.pi) * h[1] for h in col)
    deg = (math.degrees(math.atan2(y, x)) + 360) % 360
    for lim, name in ((15, "Red"), (45, "Orange"), (70, "Yellow"), (165, "Green"), (200, "Teal"), (255, "Blue"), (300, "Purple"), (345, "Pink")):
        if deg < lim: return name
    return "Red"

if "--undo" in sys.argv: undo(); sys.exit()
plan = {}
for d, _, fs in os.walk(root):
    if os.sep + "Colours" in d + os.sep: continue
    for f in sorted(fs):
        if not f.lower().endswith(EXT): continue
        p = os.path.join(d, f)
        theme = os.path.relpath(p, root).split(os.sep)[0].lower()
        dest = os.path.join(root, "Colours", folder(p), f"{theme}-{f}")
        plan[p] = dest
from collections import Counter
print(len(plan), dict(Counter(os.path.basename(os.path.dirname(v)) for v in plan.values())))
if "--apply" not in sys.argv: sys.exit()
os.makedirs(os.path.dirname(man), exist_ok=True)
for old, new in plan.items():
    os.makedirs(os.path.dirname(new), exist_ok=True); shutil.move(old, new)
json.dump({new: old for old, new in plan.items()}, open(man, "w"))
for d, _, _ in sorted(os.walk(root), key=lambda t: -len(t[0])):
    if os.sep + "Colours" in d + os.sep or d == root: continue
    try: os.rmdir(d)
    except OSError: pass
# keep shell state pointing at the moved files
sp = os.path.expanduser("~/.local/state/zerd-wallpaper.json")
if os.path.exists(sp):
    t = open(sp).read()
    for old, new in plan.items(): t = t.replace(old, new)
    open(sp, "w").write(t)
cp = os.path.expanduser("~/.config/zerda-shell/config.json")
t = open(cp).read()
for old, new in plan.items(): t = t.replace(old, new)
open(cp, "w").write(t)
for c in ("~/.cache/zerd/wallpaper-index.json", "~/.cache/quickshell/wallpaper_color_tags.json"):
    try: os.remove(os.path.expanduser(c))
    except OSError: pass
print("moved", len(plan))
