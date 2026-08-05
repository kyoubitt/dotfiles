#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="zerd"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_gtk_kde() {
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [ ! -f "$scss_file" ]; then
    return
  fi

  # Extract colors from scss (format: $colorname: #hex;)
  get_color() {
    grep "^\$$1:" "$scss_file" | cut -d: -f2 | tr -d ' ;'
  }

  local bg=$(get_color "background")
  local fg=$(get_color "onBackground")
  local primary=$(get_color "primary")
  local on_primary=$(get_color "onPrimary")
  local surface=$(get_color "surface")
  local surface_dim=$(get_color "surfaceDim")

  # Call apply-gtk-theme.sh with extracted colors
  "$SCRIPT_DIR/apply-gtk-theme.sh" "$bg" "$fg" "$primary" "$on_primary" "$surface" "$surface_dim"
}

# Ghostty reads a static "colors" config file (config-file = "colors"), not
# OSC escape sequences, so unlike apply_term() this has to write a file
# rather than inject into open ptys. Sourced from the same
# material_colors.scss the bar uses (term0-15 harmonized terminal palette),
# not wallust, so ghostty visually matches the bar/app launcher instead of
# drifting off on its own separate color-extraction algorithm.
apply_ghostty() {
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [ ! -f "$scss_file" ]; then
    return
  fi

  get_color() {
    grep "^\$$1:" "$scss_file" | cut -d: -f2 | tr -d ' ;#'
  }

  local ghostty_colors_file="$HOME/.config/ghostty/colors"
  mkdir -p "$(dirname "$ghostty_colors_file")"

  {
    echo "background = $(get_color term0)"
    echo "foreground = $(get_color term7)"
    echo "cursor-color = $(get_color term7)"
    echo "selection-background = $(get_color term8)"
    echo "selection-foreground = $(get_color term15)"
    echo ""
    for i in $(seq 0 15); do
      echo "palette = $i=$(get_color term$i)"
    done
  } > "$ghostty_colors_file"
}

# Small bg/fg/accent JSON for the waffle Start Menu (SMColors.qml), sourced
# from the same material_colors.scss as the bar and ghostty above - was
# previously wallust-sourced, which is why it used to drift out of sync.
apply_startmenu() {
  local scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [ ! -f "$scss_file" ]; then
    return
  fi

  get_color() {
    grep "^\$$1:" "$scss_file" | cut -d: -f2 | tr -d ' ;'
  }

  local out_file="$XDG_CACHE_HOME/material/startmenu-colors.json"
  mkdir -p "$(dirname "$out_file")"

  jq -n \
    --arg bg "$(get_color background)" \
    --arg fg "$(get_color onBackground)" \
    --arg accent "$(get_color primary)" \
    '{bg: $bg, fg: $fg, accent: $accent}' > "$out_file"
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/zerda-shell/config.json"
apply_pids=()
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term & apply_pids+=($!)
    apply_ghostty & apply_pids+=($!)
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term & apply_pids+=($!)
  apply_ghostty & apply_pids+=($!)
fi

# App launcher (waffle Start Menu) colors - always kept in sync with the bar
apply_startmenu & apply_pids+=($!)

# Apply GTK/KDE theming if enabled
if [ -f "$CONFIG_FILE" ]; then
  enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE")
  enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$CONFIG_FILE")
  if [ "$enable_apps_shell" != "false" ] || [ "$enable_qt_apps" != "false" ]; then
    apply_gtk_kde & apply_pids+=($!)
  fi
else
  apply_gtk_kde & apply_pids+=($!)
fi

# Apply SDDM theming if enabled
apply_sddm() {
  if [ -f "$CONFIG_DIR/scripts/sddm/sync-sddm-theme.py" ]; then
    python3 "$CONFIG_DIR/scripts/sddm/sync-sddm-theme.py" &
  fi
}

if [ -f "$CONFIG_FILE" ]; then
  enable_sddm=$(jq -r '.appearance.wallpaperTheming.enableSddm // false' "$CONFIG_FILE")
  if [ "$enable_sddm" = "true" ]; then
    apply_sddm &
  fi
fi

# Wait for the bar/ghostty/launcher/gtk color application to actually finish
# before announcing it's done - otherwise this fires before those background
# jobs above have written anything, which is misleading.
wait "${apply_pids[@]}" 2>/dev/null
notify-send "Theme" "Synced with wallpaper" -a "Theme Manager" -i "preferences-desktop-theme" -t 1500 2>/dev/null &

# Sync starship with wallust colors
if command -v wallust >/dev/null 2>&1; then
    wallust apply 2>/dev/null &
    ~/.config/wallust/fix-starship-glyphs.sh
    sleep 0.5 && python3 -c "
path=open(chr(39)+chr(47)+chr(104)+chr(111)+chr(109)+chr(101)+chr(47)+chr(122)+chr(101)+chr(114)+chr(100)+chr(97)+chr(47)+chr(46)+chr(99)+chr(111)+chr(110)+chr(102)+chr(105)+chr(103)+chr(47)+chr(115)+chr(116)+chr(97)+chr(114)+chr(115)+chr(104)+chr(105)+chr(112)+chr(47)+chr(115)+chr(116)+chr(97)+chr(114)+chr(115)+chr(104)+chr(105)+chr(112)+chr(46)+chr(116)+chr(111)+chr(109)+chr(108)+chr(39))
c=open(path).read().replace(chr(80)+chr(76)+chr(69)+chr(70)+chr(84),chr(57334)).replace(chr(80)+chr(82)+chr(73)+chr(71)+chr(72)+chr(84),chr(57268))
open(path,chr(119)).write(c)
"     wallust apply 2>/dev/null &
    ~/.config/wallust/fix-starship-glyphs.sh
fi
