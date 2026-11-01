#!/usr/bin/env bash
# Window thumbnails for the app switcher: capture each given niri window id into the preview
# cache. niri copies every screenshot to the clipboard, so the clipboard is saved first and put
# back afterwards, and the shots that reached the clipboard history are dropped again.
set -u

dir="$HOME/.cache/inir/window-previews"
mkdir -p "$dir"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ctype="$(wl-paste --list-types 2>/dev/null | head -1 || true)"
[[ -n "$ctype" ]] && wl-paste -t "$ctype" >"$tmp/clip" 2>/dev/null

before="$(cliphist list 2>/dev/null | head -1 | cut -f1 || true)"
[[ "$before" =~ ^[0-9]+$ ]] || before=0

pids=()
for id in "$@"; do
  [[ "$id" =~ ^[0-9]+$ ]] || continue
  niri msg action screenshot-window --id "$id" --path "$dir/window-$id.png" >/dev/null 2>&1 &
  pids+=("$!")
  if (( ${#pids[@]} >= 4 )); then wait "${pids[@]}"; pids=(); fi
done
(( ${#pids[@]} )) && wait "${pids[@]}"
sleep 0.15

# Drop the screenshots from the clipboard history (newer than the newest entry from before).
for _ in $(seq 1 60); do
  entry="$(cliphist list 2>/dev/null | head -1 || true)"
  eid="${entry%%$'\t'*}"
  [[ "$eid" =~ ^[0-9]+$ ]] && (( eid > before )) || break
  printf '%s\n' "$entry" | cliphist delete 2>/dev/null || break
done

# Put back what was on the clipboard (or empty it, if it had nothing), but only while it still
# holds one of our screenshots: something copied in the meantime is left alone.
now="$(wl-paste --list-types 2>/dev/null | head -1 || true)"
if [[ "$now" == "image/png" ]]; then
  if [[ -n "$ctype" && -s "$tmp/clip" ]]; then
    wl-copy -t "$ctype" <"$tmp/clip"
  else
    wl-copy --clear 2>/dev/null || true
  fi
fi
exit 0
