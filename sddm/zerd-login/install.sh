#!/usr/bin/env bash
# Installs the zerd-login SDDM theme and makes it the login screen (needs sudo once).
# Also gives SDDM your account picture, the one the lock screen shows (Config account.avatar).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest=/usr/share/sddm/themes/zerd-login
sudo rm -rf "$dest"
sudo mkdir -p "$dest"
sudo cp -r "$here"/Main.qml "$here"/metadata.desktop "$here"/theme.conf "$here"/shaders "$dest"/
# theme.conf belongs to you so scripts/theme-sync.sh can recolour it on every wallpaper change
sudo chown "$USER:$USER" "$dest/theme.conf"
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=zerd-login\n' | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null

avatar="$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.config/zerda-shell/config.json'))).get('account',{}).get('avatar',''))" 2>/dev/null || true)"
if [[ -n "$avatar" && -f "$avatar" ]]; then
  sudo mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users
  sudo install -m 644 "$avatar" "/var/lib/AccountsService/icons/$USER"
  f="/var/lib/AccountsService/users/$USER"
  if sudo test -f "$f"; then
    sudo sed -i '/^Icon=/d' "$f"
    if sudo grep -q '^\[User\]' "$f"; then sudo sed -i "/^\[User\]/a Icon=/var/lib/AccountsService/icons/$USER" "$f"
    else printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$USER" | sudo tee -a "$f" >/dev/null; fi
  else
    printf '[User]\nIcon=/var/lib/AccountsService/icons/%s\n' "$USER" | sudo tee "$f" >/dev/null
  fi
  echo "account picture installed"
fi
echo "zerd-login is set. Preview any time: sddm-greeter-qt6 --test-mode --theme $dest"
