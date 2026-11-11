# dotfiles

My Arch setup: [niri](https://github.com/YaLTeR/niri) with a custom [Quickshell](https://quickshell.org) shell called **zerd**, colours from wallust.

# DONT EXPECT UPDATES
- I dont use niri, nor arch anymore.

## What's in it

- **Top bar**: workspaces, tray, media, a clock with a calendar and weather popup, and rings for CPU, RAM, volume and battery.
- **Bar popups**: volume (drag the level capsule), battery (charge, health, power profile), system (CPU, memory, GPU, disk, network), Wi-Fi and Bluetooth, music with a working 10-band equalizer, calendar with a 16-day forecast.
- **Dock, launcher, clipboard, wallpapers, notifications, desktop widgets, side panels.**
- **Lock screen, power menu (hold to confirm) and an SDDM login theme** that follow the same palette.
- **Settings** window for the shell, and **Orbit**, a Spotify client in QML.

## Installing

For Arch and Arch-based distros:

```bash
git clone https://github.com/kyoubitt/dotfiles.git ~/.dotfiles-zerda
cd ~/.dotfiles-zerda
./install.sh
```

Needs a fresh-ish Arch install, an internet connection, sudo, and a few GB free. The script installs packages (official + AUR), symlinks configs into place, sets up Zsh, and systemd services. Takes roughly 15-30 minutes depending on your connection.

The login screen is installed separately: `./sddm/zerd-login/install.sh`.

## Using it

| Keys | |
| --- | --- |
| `Mod+A` | launcher |
| `Mod+V` | clipboard history |
| `Mod+W` | wallpapers |
| `Mod+Shift+E` | power menu |
| `Mod+Shift+Q` | lock |
| `Mod+Shift+M` | Orbit |

Everything is also reachable from a terminal: `qs -c zerd ipc call <target> <method>`, for example `barpopup open battery`.

Settings live in `~/.config/zerda-shell/config.json` and in the Settings window. Weather finds your location from your network address; set `bar.weather.city` (or the Location field in Settings) if that is wrong.

## Equalizer

The music popup's equalizer is `quickshell/zerd/modules/bars/ilya/media/zerd-audio`, a small PipeWire filter-chain (10 bands, balance, mono, swap, and the dynamics modes through the LSP compressor, `sudo pacman -S lsp-plugins`). It starts when you first use it and becomes the default output until stopped (`zerd-audio stop`).

## Credits

Modified version. Based on iNiR by snowarch (https://github.com/snowarch/inir). Code taken from it lives in `quickshell/zerd/modules/iris/` (and a few services under `quickshell/zerd/`) and keeps its `NOTICE` and GPL-3.0 `LICENSE` there.

The bar and its popups under `quickshell/zerd/modules/bars/ilya/` are ported from ilyamiro's serpantinum (AGPL-3.0). The SDDM theme is based on Darkkal44's Material You theme (MIT).

## Orbit (music)

`quickshell/zerd/modules/music/` is a Spotify client written in QML, opened with `Mod+Shift+M` or from the app menu. It needs Spotify Premium and your own free Spotify developer app: put its Client ID in `music.clientId` in `~/.config/zerda-shell/config.json`. Playback goes through Spotify's Soloist player when it is installed (`~/.local/bin/soloist`, API key in `~/.config/soloist/api-key`), or through the Spotify app. Not affiliated with Spotify.
