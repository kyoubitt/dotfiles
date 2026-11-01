#!/usr/bin/env python3
"""Writes a timeline of what niri does with the Orbit window to ~/.cache/orbit-watch.log, so that when the window
seems to vanish the log says why: which workspace it was on, when the focus or the workspace changed, and whether
the window was closed or only moved. Runs only while the Orbit window is open."""
import os, re, subprocess, sys, time

LOG = os.path.expanduser("~/.cache/orbit-watch.log")
os.makedirs(os.path.dirname(LOG), exist_ok=True)
# keep the log short: drop it when it grows past 200 KB
try:
    if os.path.getsize(LOG) > 200_000: open(LOG, "w").close()
except OSError: pass
out = open(LOG, "a", buffering=1)

def log(msg):
    out.write(time.strftime("%H:%M:%S ") + msg + "\n")

orbit_id = None
ws_of = {}
focused_ws = None
log("---- watching (the Orbit window is open)")
p = subprocess.Popen(["niri", "msg", "event-stream"], stdout=subprocess.PIPE, text=True, bufsize=1)
for line in p.stdout:
    line = line.strip()
    m = re.match(r"Window opened or changed: Window \{ id: (\d+), title: Some\(\"(.*?)\"\).*?workspace_id: (?:Some\((\d+)\)|None), is_focused: (\w+), is_floating: (\w+)", line)
    if m:
        wid, title, ws, foc, flo = m.groups()
        if title == "Orbit":
            if orbit_id != wid: log(f"Orbit window id {wid} opened on workspace {ws} (focused={foc}, floating={flo})")
            elif ws_of.get(wid) != ws: log(f"Orbit MOVED from workspace {ws_of.get(wid)} to {ws}")
            elif foc == "false": log(f"Orbit lost focus (workspace {ws}, workspace focused: {focused_ws})")
            orbit_id = wid; ws_of[wid] = ws
        continue
    m = re.match(r"Window closed: (\d+)", line)
    if m and m.group(1) == orbit_id:
        log(f"Orbit window CLOSED (id {orbit_id})"); orbit_id = None; continue
    m = re.match(r"Workspace focused: (\d+)", line)
    if m:
        focused_ws = m.group(1)
        log(f"workspace focus -> {focused_ws}" + ("  (Orbit's workspace)" if orbit_id and ws_of.get(orbit_id) == focused_ws else "  (NOT Orbit's workspace)" if orbit_id else ""))
        continue
    m = re.match(r"Window layouts changed: \[\((\d+), WindowLayout \{ pos_in_scrolling_layout: (\w+\(?[^)]*\)?)", line)
    if m and orbit_id and m.group(1) == orbit_id:
        log(f"Orbit layout position {m.group(2)}")
