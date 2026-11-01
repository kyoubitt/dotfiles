#!/usr/bin/env bash
# Fetches SFW wallpapers from Wallhaven by colour into ~/Pictures/Wallpapers/Colours/<Name>/.
# Rerunnable: colours that already have enough files are skipped. Usage: wallpaper-fetch.sh [per-colour count, default 8]
exec python3 - "${1:-8}" <<'PY'
import sys, os, json, time, urllib.request, urllib.parse
N = int(sys.argv[1])
OUT = os.path.expanduser("~/Pictures/Wallpapers/Colours")
HEX = {
  "Red": "cc0000 990000 cc3333", "Orange": "ff6600 ff9900 cc6633", "Yellow": "ffcc33 ffff00 cccc33",
  "Green": "77cc33 669900 336600", "Teal": "66cccc 0099cc", "Blue": "0066cc 333399 0099cc",
  "Purple": "663399 993399", "Pink": "ea4c88 cc3333", "Dark": "000000 424153", "Light": "ffffff cccccc",
}
QS = ["landscape illustration", "anime scenery", "digital art", "fantasy landscape", "cyberpunk city", "minimalist", "pixel art", "space"]
H = {"User-Agent": "wallpaper-fetch/1"}
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=H), timeout=60).read()
for name, hexes in HEX.items():
    d = os.path.join(OUT, name); os.makedirs(d, exist_ok=True)
    have = len([f for f in os.listdir(d) if not f.endswith(".part")])
    for hx in hexes.split():
        for q in QS:
            if have >= N: break
            url = "https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(
                {"q": q, "colors": hx, "categories": "110", "purity": "100", "atleast": "2560x1440",
                 "ratios": "16x9,16x10", "sorting": "toplist", "topRange": "1y", "order": "desc"})
            try: data = json.loads(get(url))["data"]
            except Exception: data = []
            time.sleep(1.5)
            for w in data[:14]:
                if have >= N: break
                f = os.path.join(d, os.path.basename(w["path"]))
                if os.path.exists(f) or w.get("file_size", 0) > 9_000_000: continue
                if any(os.path.exists(os.path.join(OUT, c, os.path.basename(w["path"]))) for c in HEX): continue
                try:
                    open(f + ".part", "wb").write(get(w["path"])); os.replace(f + ".part", f)
                    have += 1; print(name, os.path.basename(f), flush=True)
                except Exception: pass
                time.sleep(0.4)
PY
