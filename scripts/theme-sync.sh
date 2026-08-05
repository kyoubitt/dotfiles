#!/bin/bash

set -uo pipefail

# Source common utilities if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
else
  # Fallback logging functions if common.sh is not available
  log_info() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\\033[1;34m[$timestamp] INFO: $*\\033[0m" >&2
  }

  log_error() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\\033[1;31m[$timestamp] ERROR: $*\\033[0m" >&2
  }

  log_success() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\\033[1;32m[$timestamp] SUCCESS: $*\\033[0m" >&2
  }

  log_warn() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\\033[1;33m[$timestamp] WARN: $*\\033[0m" >&2
  }

  log_debug() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\\033[1;36m[$timestamp] DEBUG: $*\\033[0m" >&2
  }

  die() {
    log_error "$*"
    exit 1
  }

  validate_dependencies() {
    local -ra required_deps=("$@")
    local missing_deps=()

    for dep in "${required_deps[@]}"; do
      command -v "$dep" > /dev/null 2>&1 || missing_deps+=("$dep")
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
      die "Missing required dependencies: ${missing_deps[*]}"
    fi
  }
fi

# --- Configuration ---
readonly SCRIPT_NAME="${0##*/}"
readonly WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
readonly DEFAULT_GTK_THEME="Colloid-Dark"
readonly DEFAULT_ICON_THEME="Colloid-Dark"
readonly THEME_STATE_FILE="$HOME/.cache/theme-sync-state"

# Get theme based on directory and variation
map_to_gtk_theme() {
  local theme_name="$1"
  local variation="$2"

  case "${theme_name}" in
    "catppuccin")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Purple-Light"
      else
        echo "Colloid-Purple-Dark"
      fi
      ;;
    "dracula")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Pink-Light"
      else
        echo "Colloid-Pink-Dark"
      fi
      ;;
    "everforest")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Green-Light"
      else
        echo "Colloid-Green-Dark"
      fi
      ;;
    "gruvbox")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Orange-Light"
      else
        echo "Colloid-Orange-Dark"
      fi
      ;;
    "material")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Light"
      else
        echo "Colloid-Grey-Dark"
      fi
      ;;
    "nord")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Teal-Light"
      else
        echo "Colloid-Teal-Dark"
      fi
      ;;
    "solarized")
      if [[ "$variation" == "light" ]]; then
        echo "Osaka-Light-Solarized"
      else
        echo "Osaka-Dark-Solarized"
      fi
      ;;
    "rose-pine")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Pink-Light"
      else
        echo "Colloid-Pink-Dark"
      fi
      ;;
    "tokyo-night")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Purple-Light"
      else
        echo "Colloid-Purple-Dark"
      fi
      ;;
    *)
      log_warn "Unknown theme: $theme_name, using default theme"
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Light"
      else
        echo "Colloid-Dark"
      fi
      ;;
  esac
}

map_to_icon_theme() {
  local theme_name="$1"
  local variation="$2"

  case "${theme_name}" in
    "catppuccin")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Purple-Light"
      else
        echo "Colloid-Purple-Dark"
      fi
      ;;
    "dracula")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Pink-Light"
      else
        echo "Colloid-Pink-Dark"
      fi
      ;;
    "everforest")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Green-Light"
      else
        echo "Colloid-Green-Dark"
      fi
      ;;
    "gruvbox")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Orange-Light"
      else
        echo "Colloid-Orange-Dark"
      fi
      ;;
    "material")
      # Base colloid-dark for material as requested
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Light"
      else
        echo "Colloid-Dark"
      fi
      ;;
    "nord")
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Teal-Light"
      else
        echo "Colloid-Teal-Dark"
      fi
      ;;
    "solarized")
      # everforest for osaka (solarized) as requested
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Green-Light"
      else
        echo "Colloid-Green-Dark"
      fi
      ;;
    "rose-pine" | "tokyo-night")
      # catppuccin for rose-pine and tokyo-night as requested
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Purple-Light"
      else
        echo "Colloid-Purple-Dark"
      fi
      ;;
    *)
      log_warn "Unknown theme: $theme_name, using default icon theme"
      if [[ "$variation" == "light" ]]; then
        echo "Colloid-Light"
      else
        echo "Colloid-Dark"
      fi
      ;;
  esac
}

map_to_wallust_theme() {
  local theme_name="$1"
  local variation="$2"

  case "${theme_name}" in
    "catppuccin")
      if [[ "$variation" == "light" ]]; then
        echo "Catppuccin-Latte"
      else
        echo "Catppuccin-Mocha"
      fi
      ;;
    "dracula")
      if [[ "$variation" == "light" ]]; then
        echo "base16-default-light"
      else
        echo "base16-dracula"
      fi
      ;;
    "everforest")
      if [[ "$variation" == "light" ]]; then
        echo "Everforest-Light-Medium"
      else
        echo "Everforest-Dark-Medium"
      fi
      ;;
    "gruvbox")
      if [[ "$variation" == "light" ]]; then
        echo "Gruvbox"
      else
        echo "Gruvbox-Dark"
      fi
      ;;
    "material")
      if [[ "$variation" == "light" ]]; then
        echo "base16-default-light"
      else
        echo "base16-black-metal-funeral"
      fi
      ;;
    "nord")
      if [[ "$variation" == "light" ]]; then
        echo "Nord-Light"
      else
        echo "Nord"
      fi
      ;;
    "solarized")
      if [[ "$variation" == "light" ]]; then
        echo "Solarized-Light"
      else
        echo "Solarized-Dark"
      fi
      ;;
    "rose-pine")
      if [[ "$variation" == "light" ]]; then
        echo "Rosé-Pine-Dawn"
      else
        echo "Rosé-Pine"
      fi
      ;;
    "tokyo-night")
      if [[ "$variation" == "light" ]]; then
        echo "Tokyo-Night-Light"
      else
        echo "Tokyo-Night"
      fi
      ;;
    *)
      log_warn "Unknown theme: $theme_name, using random theme"
      echo "random"
      ;;
  esac
}

# --- Functions ---



detect_theme_from_wallpaper() {
  log_info "Detecting theme from current wallpaper directory"

  local wallpaper_path
  wallpaper_path=$(awww query 2> /dev/null | grep -oP '(?<=image: ).*' | head -n1 | tr -d '\n\r')

  if [[ -z "$wallpaper_path" ]]; then
    die "No wallpaper detected from awww query"
  fi

  if [[ ! -f "$wallpaper_path" ]]; then
    die "Wallpaper file does not exist: $wallpaper_path"
  fi

  log_debug "Found wallpaper: $wallpaper_path"

  local theme_dir
  theme_dir=$(dirname "$wallpaper_path")
  local parent_dir
  parent_dir=$(dirname "$theme_dir")

  local theme_name
  theme_name=$(basename "$parent_dir" | tr '[:upper:]' '[:lower:]')

  local variation
  variation=$(basename "$theme_dir" | tr '[:upper:]' '[:lower:]')

  if [[ "$theme_name" == "osaka" ]]; then
    theme_name="solarized"
  fi

  log_debug "Detected theme: $theme_name, variation: $variation"

  WALLPAPER_PATH="$wallpaper_path"
  WALLPAPER_VARIATION="$variation"
  DETECTED_THEME="$theme_name"

  export WALLPAPER_PATH WALLPAPER_VARIATION
}

check_theme_changed() {
  local -r current_theme="$1"
  local -r current_variation="$2"

  # Create cache directory if it doesn't exist
  mkdir -p "$(dirname "$THEME_STATE_FILE")"

  if [[ ! -f "$THEME_STATE_FILE" ]]; then
    log_info "No previous theme state found, this is first run or cache was cleared"
    return 0 # Theme changed (first run)
  fi

  local previous_theme previous_variation
  read -r previous_theme previous_variation < "$THEME_STATE_FILE"

  if [[ "$current_theme" == "$previous_theme" && "$current_variation" == "$previous_variation" ]]; then
    log_info "Theme unchanged: $current_theme ($current_variation)"
    return 1 # Theme did not change
  else
    log_info "Theme changed: $previous_theme ($previous_variation) → $current_theme ($current_variation)"
    return 0 # Theme changed
  fi
}

save_theme_state() {
  local -r theme="$1"
  local -r variation="$2"

  mkdir -p "$(dirname "$THEME_STATE_FILE")"
  echo "$theme $variation" > "$THEME_STATE_FILE"
  log_info "Saved theme state: $theme ($variation)"
}

# Function to set values in INI files
set_ini_value() {
  local -r file="$1"
  local -r section="$2"
  local -r key="$3"
  local -r value="$4"

  [[ -f "$file" ]] || touch "$file"

  if grep -q "^\\[$section\\]" "$file"; then
    if grep -q "^$key=" "$file"; then
      sed -i "/^\\[$section\\]/,/^\\[/ s/^$key=.*/$key=$value/" "$file"
    else
      sed -i "/^\\[$section\\]/a $key=$value" "$file"
    fi
  else
    printf '\\n[%s]\\n%s=%s\\n' "$section" "$key" "$value" >> "$file"
  fi
}

manage_gtk_config() {
  local -r version="$1"
  local -r theme="$2"
  local -r variation="${3:-dark}"
  local -r config_file="$HOME/.config/gtk-$version/settings.ini"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$config_file")"

  set_ini_value "$config_file" "Settings" "gtk-theme-name" "$theme"

  # Set prefer-dark-theme based on variation
  if [[ "$variation" == "light" ]]; then
    set_ini_value "$config_file" "Settings" "gtk-application-prefer-dark-theme" "0"
  else
    set_ini_value "$config_file" "Settings" "gtk-application-prefer-dark-theme" "1"
  fi
}

update_xsettingsd() {
  local -r theme="$1"
  local -r icon_theme="$2"
  local -r config_file="$HOME/.config/xsettingsd/xsettingsd.conf"

  # Create directory if it doesn't exist
  mkdir -p "$(dirname "$config_file")"

  # Check if file exists, create it with proper format if it doesn't
  if [[ ! -f "$config_file" ]]; then
    printf 'Net/ThemeName "%s"
Net/IconThemeName "%s"
' "$theme" "$icon_theme" > "$config_file"
  else
    sed -i "s/Net\/ThemeName \".*\"/Net\/ThemeName \"$theme\"/; s/Net\/IconThemeName \".*\"/Net\/IconThemeName \"$icon_theme\"/" "$config_file" 2> /dev/null ||
      log_warn "Failed to update xsettingsd config for theme name"
  fi
}

update_gtk_settings() {
  local -r gtk_theme="$1"
  local -r variation="$2"

  # Set the GTK theme using gsettings
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2> /dev/null || {
    log_warn "Failed to set GTK theme via gsettings, may not be available"
  }

  # Set color scheme based on variation
  if [[ "$variation" == "light" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light" 2> /dev/null || {
      log_warn "Failed to set light color scheme via gsettings"
    }
  else
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2> /dev/null || {
      log_warn "Failed to set dark color scheme via gsettings"
    }
  fi

  # Force reload of GTK settings for running applications
  if command -v dbus-send > /dev/null 2>&1; then
    dbus-send --session --dest=org.gtk.Settings --type=method_call \
      /org/gtk/Settings org.gtk.Settings.NotifyThemeChange 2> /dev/null || true
  fi

  # Reload xsettingsd if running
  if command -v pgrep > /dev/null 2>&1 && command -v pkill > /dev/null 2>&1; then
    if pgrep -x xsettingsd > /dev/null; then
      pkill -HUP xsettingsd
    fi
  else
    log_warn "pgrep/pkill not available, skipping xsettingsd reload"
  fi
}

manage_symlinks() {
  local -r theme="$1"
  local target_dir=""

  # Find theme directory
  local -ra theme_paths=(
    "$HOME/.themes/$theme"
    "$HOME/.local/share/themes/$theme"
    "/usr/share/themes/$theme"
  )

  for path in "${theme_paths[@]}"; do
    if [[ -d "$path" ]]; then
      target_dir="$path"
      break
    fi
  done

  [[ -n "$target_dir" ]] || {
    log_warn "Theme assets not found: $theme, skipping symlinks"
    return 1
  }

  # Create symlinks for GTK 4.0
  local -r gtk4_dir="$HOME/.config/gtk-4.0"
  mkdir -p "$gtk4_dir"

  declare -A links=(
    ["$gtk4_dir/gtk.css"]="gtk-4.0/gtk.css"
    ["$gtk4_dir/gtk-dark.css"]="gtk-4.0/gtk-dark.css"
    ["$gtk4_dir/assets"]="gtk-4.0/assets"
  )

  # Create symlinks
  for link in "${!links[@]}"; do
    local target="$target_dir/${links[$link]}"
    [[ -e "$target" ]] || continue

    mkdir -p "$(dirname "$link")"
    ln -sf "$target" "$link" && log_info "Created symlink: ${link##*/}"
  done
}

set_gtk_theme() {
  local -r gtk_theme="$1"
  local -r variation="${2:-dark}"
  local -r icon_theme="${3:-$DEFAULT_ICON_THEME}"

  log_info "Setting GTK theme to: $gtk_theme"

  # Check if theme directory exists
  local theme_found=0
  local -ra theme_paths=(
    "$HOME/.themes/$gtk_theme"
    "$HOME/.local/share/themes/$gtk_theme"
    "/usr/share/themes/$gtk_theme"
  )

  for path in "${theme_paths[@]}"; do
    if [[ -d "$path" ]]; then
      theme_found=1
      break
    fi
  done

  if [[ $theme_found -eq 0 ]]; then
    log_warn "GTK theme not found: $gtk_theme, skipping theme change"
    return
  fi

  # Apply theme through multiple methods to ensure coverage
  update_gtk_settings "$gtk_theme" "$variation"
  manage_gtk_config "3.0" "$gtk_theme" "$variation"
  manage_gtk_config "4.0" "$gtk_theme" "$variation"
  manage_symlinks "$gtk_theme"
  update_xsettingsd "$gtk_theme" "$icon_theme"

  log_success "GTK theme set to: $gtk_theme with comprehensive configuration"
}

set_icon_theme() {
  local -r icon_theme="$1"

  log_info "Setting icon theme to: $icon_theme"

  # Check if icon theme directory exists
  local theme_found=0
  local -ra icon_theme_paths=(
    "$HOME/.icons/$icon_theme"
    "$HOME/.local/share/icons/$icon_theme"
    "/usr/share/icons/$icon_theme"
  )

  for path in "${icon_theme_paths[@]}"; do
    if [[ -d "$path" ]]; then
      theme_found=1
      break
    fi
  done

  if [[ $theme_found -eq 0 ]]; then
    log_warn "Icon theme not found: $icon_theme, skipping icon theme change"
    return
  fi

  # Set the icon theme
  gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" || {
    log_warn "Failed to set icon theme, gsettings may not be available"
  }

  log_success "Icon theme set to: $icon_theme"
}

run_wallust_theme() {
  local -r wallpaper_path="$2"
  log_info "Running wallust on wallpaper: $wallpaper_path"
  if ! wallust run "$wallpaper_path" 2> /dev/null; then
    log_warn "Wallust generation failed, continuing..."
  else
    log_success "Wallust theme generation completed"
  fi
}

update_niri_config() {
  local -r niri_config_file="$HOME/.config/niri/config.kdl"
  local -r wallust_colors_file="$HOME/.cache/wallust/colors.json"

  if [[ ! -f "$wallust_colors_file" ]]; then
    log_warn "Wallust color cache not found, skipping niri config update"
    return
  fi

  local background_color
  background_color=$(jq -r '.special.background' "$wallust_colors_file")

  if [[ -z "$background_color" ]]; then
    log_warn "Could not extract background color from wallust cache"
    return
  fi

  log_info "Updating niri config with background color: $background_color"

  # Only change active-color within the focus-ring block
  sed -i "/focus-ring {/,/}/ s/active-color \".*\"/active-color \"$background_color\"/" "$niri_config_file"
  # Only change color within the insert-hint block
  sed -i "/insert-hint {/,/}/ s/color \".*\"/color \"$background_color\"/" "$niri_config_file"

  log_success "Niri config updated successfully"
}

update_sddm_theme() {
  local -r wallpaper_path="$1"
  local -r sddm_conf="/usr/share/sddm/themes/sddm-astronaut-theme/Themes/wallust.conf"
  local -r sddm_bg_cache="/var/cache/sddm-wallust/background.jpg"
  local -r wallust_colors_file="$HOME/.cache/wallust/colors.json"

  if [[ ! -f "$sddm_conf" ]]; then
    log_warn "SDDM wallust theme not found, skipping SDDM sync"
    return
  fi

  if [[ ! -w "$sddm_conf" ]]; then
    log_warn "SDDM theme config not writable, skipping SDDM sync"
    return
  fi

  if [[ ! -d "$(dirname "$sddm_bg_cache")" || ! -w "$(dirname "$sddm_bg_cache")" ]]; then
    log_warn "SDDM background cache dir not writable, skipping SDDM sync"
    return
  fi

  if [[ ! -f "$wallust_colors_file" ]]; then
    log_warn "Wallust color cache not found, skipping SDDM sync"
    return
  fi

  local background foreground color0 color3 color4 color6 color7
  background=$(jq -r '.special.background' "$wallust_colors_file")
  foreground=$(jq -r '.special.foreground' "$wallust_colors_file")
  color0=$(jq -r '.colors.color0' "$wallust_colors_file")
  color3=$(jq -r '.colors.color3' "$wallust_colors_file")
  color4=$(jq -r '.colors.color4' "$wallust_colors_file")
  color6=$(jq -r '.colors.color6' "$wallust_colors_file")
  color7=$(jq -r '.colors.color7' "$wallust_colors_file")

  cp "$wallpaper_path" "$sddm_bg_cache"

  # sed -i needs write access to the containing directory (for its atomic
  # temp-file swap), which is root-owned even though the file itself isn't.
  # Write through the existing file handle instead, which only needs the
  # file to be writable.
  local sddm_conf_tmp
  sddm_conf_tmp=$(mktemp)

  sed \
    -e "s/^HeaderTextColor=.*/HeaderTextColor=\"$foreground\"/" \
    -e "s/^DateTextColor=.*/DateTextColor=\"$foreground\"/" \
    -e "s/^TimeTextColor=.*/TimeTextColor=\"$foreground\"/" \
    -e "s/^FormBackgroundColor=.*/FormBackgroundColor=\"$background\"/" \
    -e "s/^BackgroundColor=.*/BackgroundColor=\"$background\"/" \
    -e "s/^DimBackgroundColor=.*/DimBackgroundColor=\"$background\"/" \
    -e "s/^LoginFieldBackgroundColor=.*/LoginFieldBackgroundColor=\"$color0\"/" \
    -e "s/^PasswordFieldBackgroundColor=.*/PasswordFieldBackgroundColor=\"$color0\"/" \
    -e "s/^LoginFieldTextColor=.*/LoginFieldTextColor=\"$foreground\"/" \
    -e "s/^PasswordFieldTextColor=.*/PasswordFieldTextColor=\"$foreground\"/" \
    -e "s/^UserIconColor=.*/UserIconColor=\"$foreground\"/" \
    -e "s/^PasswordIconColor=.*/PasswordIconColor=\"$foreground\"/" \
    -e "s/^PlaceholderTextColor=.*/PlaceholderTextColor=\"$color7\"/" \
    -e "s/^WarningColor=.*/WarningColor=\"$color3\"/" \
    -e "s/^LoginButtonTextColor=.*/LoginButtonTextColor=\"$background\"/" \
    -e "s/^LoginButtonBackgroundColor=.*/LoginButtonBackgroundColor=\"$color4\"/" \
    -e "s/^SystemButtonsIconsColor=.*/SystemButtonsIconsColor=\"$foreground\"/" \
    -e "s/^SessionButtonTextColor=.*/SessionButtonTextColor=\"$foreground\"/" \
    -e "s/^VirtualKeyboardButtonTextColor=.*/VirtualKeyboardButtonTextColor=\"$foreground\"/" \
    -e "s/^DropdownTextColor=.*/DropdownTextColor=\"$foreground\"/" \
    -e "s/^DropdownSelectedBackgroundColor=.*/DropdownSelectedBackgroundColor=\"$color4\"/" \
    -e "s/^DropdownBackgroundColor=.*/DropdownBackgroundColor=\"$background\"/" \
    -e "s/^HighlightTextColor=.*/HighlightTextColor=\"$background\"/" \
    -e "s/^HighlightBackgroundColor=.*/HighlightBackgroundColor=\"$color4\"/" \
    -e "s/^HighlightBorderColor=.*/HighlightBorderColor=\"$color4\"/" \
    -e "s/^HoverUserIconColor=.*/HoverUserIconColor=\"$color6\"/" \
    -e "s/^HoverPasswordIconColor=.*/HoverPasswordIconColor=\"$color6\"/" \
    -e "s/^HoverSystemButtonsIconsColor=.*/HoverSystemButtonsIconsColor=\"$color6\"/" \
    -e "s/^HoverSessionButtonTextColor=.*/HoverSessionButtonTextColor=\"$color6\"/" \
    -e "s/^HoverVirtualKeyboardButtonTextColor=.*/HoverVirtualKeyboardButtonTextColor=\"$color6\"/" \
    "$sddm_conf" > "$sddm_conf_tmp"

  cat "$sddm_conf_tmp" > "$sddm_conf"
  rm -f "$sddm_conf_tmp"

  log_success "SDDM theme synced with current wallpaper/colors"
}

main() {
  log_info "Starting dynamic theme synchronization"

  sleep 0.8 # let awww set the wallpaper before we query it below

  # Validate dependencies
  validate_dependencies "awww" "wallust" "jq" "sed" "grep" "head" "tr"

  # Detect theme from current wallpaper
  detect_theme_from_wallpaper

  local detected_theme="${DETECTED_THEME:-}"
  local wallpaper_path="${WALLPAPER_PATH:-}"
  local wallpaper_variation="${WALLPAPER_VARIATION:-}"

  if [[ -z "$detected_theme" ]]; then
    die "Unable to determine theme from current wallpaper"
  fi

  if [[ -z "$wallpaper_path" || ! -f "$wallpaper_path" ]]; then
    die "Wallpaper file does not exist: ${wallpaper_path:-unknown}"
  fi

  if [[ -z "$wallpaper_variation" ]]; then
    die "Unable to determine wallpaper variation"
  fi

  log_info "Detected theme: $detected_theme, variation: $wallpaper_variation"

  # Check if theme/variation changed
  local theme_changed=0
  theme_changed=1  # Always sync

  # Map to appropriate themes using both theme and variation
  local gtk_theme
  gtk_theme=$(map_to_gtk_theme "$detected_theme" "$wallpaper_variation")

  local icon_theme
  icon_theme=$(map_to_icon_theme "$detected_theme" "$wallpaper_variation")

  local wallust_theme
  wallust_theme=$(map_to_wallust_theme "$detected_theme" "$wallpaper_variation")

  # Only apply themes if theme/variation changed
  if [[ $theme_changed -eq 1 ]]; then
    set_gtk_theme "$gtk_theme" "$wallpaper_variation" "$icon_theme"
    set_icon_theme "$icon_theme"
    run_wallust_theme "$wallust_theme" "$wallpaper_path"
    update_niri_config
    update_sddm_theme "$wallpaper_path"

    if command -v makoctl > /dev/null 2>&1; then
      makoctl reload 2> /dev/null || log_warn "Failed to reload mako"
    else
      log_warn "makoctl not available, skipping notification daemon reload"
    fi

    save_theme_state "$detected_theme" "$wallpaper_variation"

    log_success "Dynamic theme synchronization completed successfully"
    send_notification "Theme Manager" "Theme Synchronization Complete" "" "normal" "preferences-desktop-theme"
  else
    log_info "Theme unchanged, skipping all theming operations"
    log_success "Wallpaper applied, no theme changes needed"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

