#!/usr/bin/env python3
"""Classify wallpaper images into rough color buckets by average hue/saturation.
Usage: tag_wallpaper_colors.py <directory>
Prints "<absolute_path>\t<ColorName>" per line, recursively, for image files.

Results are cached (keyed by path + mtime + size) in
$XDG_CACHE_HOME/quickshell/wallpaper_color_tags.json so repeat runs over the
same library only classify new/changed files instead of re-decoding every
image from scratch every time the picker opens.
"""
import sys
import os
import json
import colorsys

from PIL import Image

BUCKETS = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink"]
EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")

CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "quickshell"
)
CACHE_PATH = os.path.join(CACHE_DIR, "wallpaper_color_tags.json")


def load_cache():
    try:
        with open(CACHE_PATH, "r") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp_path = CACHE_PATH + ".tmp"
        with open(tmp_path, "w") as f:
            json.dump(cache, f)
        os.replace(tmp_path, CACHE_PATH)
    except OSError:
        pass


def classify(path):
    try:
        img = Image.open(path).convert("RGB")
        img = img.resize((32, 32))
        pixels = list(img.getdata())
        r = sum(p[0] for p in pixels) / len(pixels)
        g = sum(p[1] for p in pixels) / len(pixels)
        b = sum(p[2] for p in pixels) / len(pixels)
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s < 0.15 or v < 0.12:
            return "Monochrome"
        deg = h * 360
        if deg < 15 or deg >= 345:
            return "Red"
        if deg < 45:
            return "Orange"
        if deg < 70:
            return "Yellow"
        if deg < 170:
            return "Green"
        if deg < 255:
            return "Blue"
        if deg < 300:
            return "Purple"
        return "Pink"
    except Exception:
        return "Monochrome"


def main():
    root = sys.argv[1]
    cache = load_cache()
    dirty = False

    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if not f.lower().endswith(EXTENSIONS):
                continue
            full = os.path.join(dirpath, f)
            try:
                st = os.stat(full)
            except OSError:
                continue
            key = full
            fingerprint = f"{st.st_mtime_ns}:{st.st_size}"

            entry = cache.get(key)
            if entry is not None and entry.get("fingerprint") == fingerprint:
                color = entry["color"]
            else:
                color = classify(full)
                cache[key] = {"fingerprint": fingerprint, "color": color}
                dirty = True

            print(f"{full}\t{color}", flush=True)

    if dirty:
        save_cache(cache)


if __name__ == "__main__":
    main()
