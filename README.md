# dotfiles

## Installing

For Arch and Arch-based distros:

```bash
git clone https://github.com/kyoubitt/dotfiles.git ~/.dotfiles-zerda
cd ~/.dotfiles-zerda
./install.sh
```

Needs a fresh-ish Arch install, an internet connection, sudo, and a few GB free. The script installs packages (official + AUR), symlinks configs into place, sets up Zsh, and systemd services. Takes roughly 15-30 minutes depending on your connection.

## Credits

Modified version. Based on iNiR by snowarch (https://github.com/snowarch/inir). Code taken from it lives in `quickshell/zerd/modules/iris/` (and a few services under `quickshell/zerd/`) and keeps its `NOTICE` and GPL-3.0 `LICENSE` there.

## Orbit (music)

`quickshell/zerd/modules/music/` is a Spotify client written in QML, opened with `Mod+Shift+M` or from the app menu. It needs Spotify Premium and your own free Spotify developer app: put its Client ID in `music.clientId` in `~/.config/zerda-shell/config.json` (nothing secret is stored in this repo). Playback goes through Spotify's Soloist player when it is installed (`~/.local/bin/soloist`, API key in `~/.config/soloist/api-key`), or through the Spotify app. Not affiliated with Spotify.
