# dotfiles

My personal Arch Linux desktop setup, built around [niri](https://github.com/YaLTeR/niri) and a custom [Quickshell](https://quickshell.org/) shell.

## Installing

For Arch and Arch-based distros:

```bash
git clone https://github.com/kyoubitt/dotfiles.git ~/.dotfiles-zerda
cd ~/.dotfiles-zerda
./install.sh
```

Needs a fresh-ish Arch install, an internet connection, sudo, and a few GB free. The script installs packages (official + AUR), symlinks configs into place, sets up Zsh, and systemd services. Takes roughly 15-30 minutes depending on your connection.

## Keybinds

`Mod` is the Super/Windows key.

### Apps

| Keybind | Action |
| --- | --- |
| `Mod + Return` | Terminal (Ghostty) |
| `Mod + B` | Browser |
| `Mod + A` | App launcher |
| `Mod + E` | File manager |
| `Mod + W` | Wallpaper selector |
| `Mod + Shift + B` | Toggle status bar |
| `Mod + Shift + Q` | Lock screen |
| `Mod + Shift + E` | Power menu |
| `Mod + P` | Color picker |
| `Mod + S` / `Mod + Shift + S` / `Mod + Ctrl + S` | Screenshot (selection / full screen / window) |

### Media

Standard media keys (volume, mic mute, brightness, play/pause/next/prev) all work, including while the screen is locked.

### Window management

| Keybind | Action |
| --- | --- |
| `Mod + H/J/K/L` or arrow keys | Focus window/workspace in that direction |
| `Mod + Shift + H/J/K/L` | Move column/window in that direction |
| `Mod + 1-9` | Switch to workspace 1-9 |
| `Mod + Shift + 1-9` | Move window to workspace 1-9 |
| `Mod + Tab` | Previous workspace |
| `Mod + Escape` | Overview mode |
| `Mod + Q` | Close window |
| `Mod + T` | Toggle floating |
| `Mod + F` | Fullscreen |
| `Mod + M` | Maximize column |
| `Mod + C` / `Mod + Ctrl + C` | Center column / center all columns |

Full list (including monitor management and layout sizing) is in `niri/config.kdl`.
