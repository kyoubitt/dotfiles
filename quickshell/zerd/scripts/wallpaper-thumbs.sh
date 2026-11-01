#!/usr/bin/env bash
# Thumbnails for the wallpaper picker, so it never has to decode the original (up to 13 MB each).
# Prints the hash of every thumbnail that exists (first) or gets made (as it is made), the current
# wallpaper first. ~/.cache/zerd/wallpaper-thumbs/<md5 of the path>.jpg, 1100x620 at most.
src="${1:-$HOME/Pictures/Wallpapers}"
cur="${2:-}"
out="$HOME/.cache/zerd/wallpaper-thumbs"
mkdir -p "$out"

hash() { printf '%s' "$1" | md5sum | cut -d' ' -f1; }
make() {
  local f="$1" h
  h="$(hash "$f")"
  if nice -n 19 vipsthumbnail "$f" -s 1100x620 -o "$out/$h.jpg[Q=82]" 2>/dev/null; then echo "$h"; else rm -f "$out/$h.jpg"; fi
}
export -f hash make
export out

todo=()
while IFS= read -r -d '' f; do
  h="$(hash "$f")"
  t="$out/$h.jpg"
  if [[ -s "$t" && ! "$f" -nt "$t" ]]; then echo "$h"
  elif [[ "$f" == "$cur" ]]; then todo=("$f" "${todo[@]}")
  else todo+=("$f")
  fi
done < <(find "$src" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0)

if (( ${#todo[@]} > 0 )); then
  printf '%s\0' "${todo[@]}" | xargs -0 -P3 -n1 bash -c 'make "$0"'
fi
exit 0
