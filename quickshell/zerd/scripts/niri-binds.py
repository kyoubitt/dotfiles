#!/usr/bin/env python3
"""Reads and rebinds the single-line binds of niri's config.
   niri-binds.py list                 -> JSON [{key, props, action, title, line}]
   niri-binds.py rebind OLD NEW       -> prints ok, or the reason it did not change anything
The config is backed up first and checked with `niri validate`; a bad result is rolled back."""
import sys, os, re, json, shutil, subprocess

CFG = os.path.expanduser("~/.config/niri/config.kdl")
LINE = re.compile(r'^(\s*)(\S+)((?:\s+[\w-]+=(?:"[^"]*"|\S+))*)\s*\{(.*)\}\s*$')

def binds_range(lines):
    start = next((i for i, l in enumerate(lines) if re.match(r'^binds\s*\{', l)), None)
    if start is None: return None, None
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0: return start, i
    return start, len(lines) - 1

def parse():
    lines = open(CFG).read().split("\n")
    a, b = binds_range(lines)
    out = []
    if a is None: return lines, out
    for i in range(a + 1, b):
        l = lines[i]
        if l.strip().startswith("//"): continue
        m = LINE.match(l)
        if not m: continue
        key, props, body = m.group(2), m.group(3).strip(), m.group(4).strip().rstrip(";").strip()
        t = re.search(r'hotkey-overlay-title="([^"]*)"', props)
        out.append({"key": key, "props": props, "action": body, "title": t.group(1) if t else "", "line": i})
    return lines, out

cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
if cmd == "list":
    print(json.dumps(parse()[1]))
elif cmd == "rebind" and len(sys.argv) == 4:
    old, new = sys.argv[2], sys.argv[3]
    lines, binds = parse()
    if any(b["key"] == new for b in binds):
        print("already used by another shortcut"); sys.exit()
    target = next((b for b in binds if b["key"] == old), None)
    if not target:
        print("shortcut not found"); sys.exit()
    shutil.copy(CFG, CFG + ".bak-binds")
    i = target["line"]
    lines[i] = lines[i].replace(old, new, 1)
    open(CFG, "w").write("\n".join(lines))
    r = subprocess.run(["niri", "validate"], capture_output=True, text=True)
    if r.returncode != 0:
        shutil.copy(CFG + ".bak-binds", CFG)
        print("niri did not accept that key, nothing changed")
    else:
        print("ok")
else:
    print("usage: niri-binds.py list | rebind OLD NEW")
