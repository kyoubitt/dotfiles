#!/bin/bash
# Syncs Thunar's GTK theme + icon theme to the current wallust palette
# (~/.cache/wallust/colors.json). Called from switchwall.sh right after
# `wallust run`. Picks the closest-hue Colloid accent variant instead of
# generating a one-off CSS, since Colloid is already the icon/theme base
# used everywhere else and stays clean/minimal instead of "AI-generic".
set -uo pipefail

WALLUST_COLORS="$HOME/.cache/wallust/colors.json"
GTK3_INI="$HOME/.config/gtk-3.0/settings.ini"
GTK4_INI="$HOME/.config/gtk-4.0/settings.ini"

[[ -f "$WALLUST_COLORS" ]] || exit 0

read -r accent variation <<< "$(python3 -c "
import json, colorsys
d = json.load(open('$WALLUST_COLORS'))

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

r, g, b = hex_to_rgb(d['colors']['color4'])
h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
hue = h * 360

if s < 0.18:
    accent = 'Grey'
elif hue < 15 or hue >= 345:
    accent = 'Red'
elif hue < 45:
    accent = 'Orange'
elif hue < 70:
    accent = 'Yellow'
elif hue < 160:
    accent = 'Green'
elif hue < 235:
    accent = 'Teal'
elif hue < 290:
    accent = 'Purple'
else:
    accent = 'Pink'

br, bgc, bb = hex_to_rgb(d['special']['background'])
bg_luma = (0.299 * br + 0.587 * bgc + 0.114 * bb) / 255
variation = 'Light' if bg_luma > 0.5 else 'Dark'

print(accent, variation)
")"

[[ -n "${accent:-}" && -n "${variation:-}" ]] || exit 0

# User gtk.css overrides don't apply in this environment (confirmed with a
# universal `* { outline: ... }` test - zero effect). Theme *selection*
# does work, so instead of styling on top of Colloid, generate a recolored
# copy of it and select that instead. Colloid's CSS bakes literal hex
# values into each rule rather than using variables, but the palette is
# small and consistent - find/replace the known hex values in a copy.
template_theme="Colloid-${variation}"
template_dir=""
for path in "$HOME/.themes/$template_theme" "$HOME/.local/share/themes/$template_theme" "/usr/share/themes/$template_theme"; do
    [[ -d "$path" ]] && template_dir="$path" && break
done

theme_name="Colloid-${variation}"

if [[ -n "$template_dir" ]]; then
    generated_name="Colloid-Wallust-${variation}"
    generated_dir="$HOME/.themes/$generated_name"
    rm -rf "$generated_dir"
    mkdir -p "$HOME/.themes"
    cp -r "$template_dir" "$generated_dir"

    python3 -c "
import json, re

d = json.load(open('$WALLUST_COLORS'))

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(c))) for c in rgb)

def blend(c1, c2, t):
    r1, g1, b1 = hex_to_rgb(c1)
    r2, g2, b2 = hex_to_rgb(c2)
    return rgb_to_hex((r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t))

def shade(h, delta):
    r, g, b = hex_to_rgb(h)
    return rgb_to_hex((r + delta, g + delta, b + delta))

bg = d['special']['background']
fg = d['special']['foreground']
accent = d['colors']['color4']
accent_r, accent_g, accent_b = hex_to_rgb(accent)
surface = blend(bg, accent, 0.15)

variation = '$variation'

if variation == 'Dark':
    # Same shade deltas Colloid-Dark itself uses (base #2C2C2C / accent
    # #5b9bf8), just recentered on the wallust surface color - preserves
    # the shading relationships (hover lighter, etc) with the new palette.
    mapping = {
        '#2C2C2C': surface,
        '#242424': shade(surface, -8),
        '#212121': shade(surface, -11),
        '#3C3C3C': shade(surface, 16),
        '#454545': shade(surface, 25),
        '#FFFFFF': fg,
        '#5b9bf8': accent,
    }
    accent_rgba_old = '91, 155, 248'
else:
    mapping = {
        '#FFFFFF': surface,
        '#FAFAFA': shade(surface, -6),
        '#F2F2F2': shade(surface, -13),
        '#f2f2f2': shade(surface, -13),
        '#e0e0e0': shade(surface, -25),
        '#3c84f7': accent,
    }
    accent_rgba_old = '60, 132, 247'

for relpath in ('gtk-3.0/gtk.css', 'gtk-3.0/gtk-dark.css', 'gtk-4.0/gtk.css', 'gtk-4.0/gtk-dark.css'):
    path = '$generated_dir/' + relpath
    try:
        css = open(path).read()
    except FileNotFoundError:
        continue
    for old, new in mapping.items():
        css = re.sub(re.escape(old), new, css, flags=re.IGNORECASE)
    # Accent also shows up as rgba(r, g, b, alpha) for hover/ripple/focus
    # tints (e.g. rgba(91, 155, 248, 0.2)) - the hex-only pass above misses
    # these, leaving old-accent-colored glows even after everything else
    # is recolored. Keep the original alpha, swap just the rgb triple.
    css = re.sub(
        r'rgba\(\s*' + re.escape(accent_rgba_old) + r'\s*,',
        f'rgba({accent_r}, {accent_g}, {accent_b},',
        css,
    )
    open(path, 'w').write(css)
"

    if [[ -f "$generated_dir/index.theme" ]]; then
        sed -i "s/^Name=.*/Name=$generated_name/" "$generated_dir/index.theme"
    fi

    # A *new* theme name is only discovered from ~/.local/share/themes here,
    # not ~/.themes (confirmed: ~/.themes alone silently fell back to
    # Colloid's original colors). Writing both anyway since ~/.themes is
    # where switching between the pre-existing Colloid variants has always
    # worked reliably.
    rm -rf "$HOME/.local/share/themes/$generated_name"
    mkdir -p "$HOME/.local/share/themes"
    cp -r "$generated_dir" "$HOME/.local/share/themes/$generated_name"

    theme_name="$generated_name"
fi

# Icon theme stays on Colloid's own accent-variant icons (SVGs - not
# something the hex find-replace above can safely touch), matched by hue
# bucket same as before, independent of the generated GTK theme above.
icon_theme_name="Colloid-${accent}-${variation}"
icon_found=0
for path in "$HOME/.icons/$icon_theme_name" "$HOME/.local/share/icons/$icon_theme_name" "/usr/share/icons/$icon_theme_name"; do
    [[ -d "$path" ]] && icon_found=1 && break
done
[[ $icon_found -eq 1 ]] || icon_theme_name="Colloid-${variation}"

gsettings set org.gnome.desktop.interface gtk-theme "$theme_name" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "$icon_theme_name" 2>/dev/null

set_ini_value() {
    # sed -i does a rename-swap under the hood, which would replace $file's
    # symlink (settings.ini -> dotfiles repo) with a plain file instead of
    # editing through it. Resolve to the real path first so the repo copy
    # is what actually gets edited and the symlink stays intact.
    local file="$1" key="$2" value="$3"
    mkdir -p "$(dirname "$file")"
    [[ -e "$file" ]] || printf '[Settings]\n' > "$file"
    local real_file
    real_file=$(readlink -f "$file")
    if grep -q "^$key=" "$real_file"; then
        sed -i "s|^$key=.*|$key=$value|" "$real_file"
    else
        sed -i "/^\[Settings\]/a $key=$value" "$real_file"
    fi
}

set_ini_value "$GTK3_INI" "gtk-theme-name" "$theme_name"
set_ini_value "$GTK3_INI" "gtk-icon-theme-name" "$icon_theme_name"
set_ini_value "$GTK4_INI" "gtk-theme-name" "$theme_name"
set_ini_value "$GTK4_INI" "gtk-icon-theme-name" "$icon_theme_name"

# zerda-shell's IconThemeService restores appearance.iconTheme from
# config.json into gsettings on every shell config reload (its own
# "persist across restarts" feature) - if that field is stale, it silently
# stomps the icon-theme gsettings value straight back over whatever this
# script just set. Keep it in lockstep so the shell's own restore logic
# never fights this one.
SHELL_CONFIG="$HOME/.config/zerda-shell/config.json"
if [[ -f "$SHELL_CONFIG" ]]; then
    jq --arg theme "$icon_theme_name" '.appearance.iconTheme = $theme' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp" \
        && mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
fi
