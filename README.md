# dotfiles

## Installing

For Arch and Arch-based distros:

```bash
git clone https://github.com/kyoubitt/dotfiles.git ~/.dotfiles-zerda
cd ~/.dotfiles-zerda
./install.sh
```

Needs a fresh-ish Arch install, an internet connection, sudo, and a few GB free. The script installs packages (official + AUR), symlinks configs into place, sets up Zsh, and systemd services. Takes roughly 15-30 minutes depending on your connection.
