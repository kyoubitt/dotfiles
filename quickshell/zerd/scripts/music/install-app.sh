#!/usr/bin/env bash
# Adds Orbit to the app menu and the dock list: a desktop entry that opens the music window, plus its icon.
set -e
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
icons="$HOME/.local/share/icons/hicolor/scalable/apps"
apps="$HOME/.local/share/applications"
mkdir -p "$icons" "$apps"
cp "$here/assets/icons/orbit.svg" "$icons/orbit.svg"
cat > "$apps/orbit.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Orbit
GenericName=Music
Comment=A QML client for Spotify
Exec=qs -c zerd ipc call music open
Icon=orbit
Terminal=false
Categories=AudioVideo;Audio;Player;
Keywords=spotify;music;player;
StartupNotify=false
DESK
command -v update-desktop-database >/dev/null && update-desktop-database "$apps" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "Orbit added to the app menu"
