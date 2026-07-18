#!/bin/bash
# Start polkit agent
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Start awww daemon for wallpaper
awww-daemon &

# Restore last wallpaper
sleep 1 && awww img "$(cat ~/.cache/awww/last-wallpaper 2>/dev/null)" -t fade --transition-duration 2 --transition-fps 30 &

# Start quickshell (wallpaper selector, panels, etc.)
qs -c zerd > ~/.cache/quickshell-zerd.log 2>&1 &
