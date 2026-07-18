#!/usr/bin/env bash
# Restarts the quickshell "zerd" shell and reports success/failure via a
# notification. mako's config already pulls live wallust colors, so this
# notification matches the current wallpaper theme with no extra work.

QS_CONFIG="zerd"
LOG="$HOME/.cache/quickshell-zerd.log"

pkill -f "qs -c $QS_CONFIG"

for _ in $(seq 1 20); do
    pgrep -f "^qs -c $QS_CONFIG\$" >/dev/null 2>&1 || break
    sleep 0.1
done

nohup qs -c "$QS_CONFIG" > "$LOG" 2>&1 &
disown

for _ in $(seq 1 30); do
    if pgrep -f "^qs -c $QS_CONFIG\$" >/dev/null 2>&1; then
        notify-send "Quickshell reloaded" -a "Shell" -i "view-refresh"
        exit 0
    fi
    sleep 0.1
done

notify-send "Quickshell reload failed" -a "Shell" -u critical -i "dialog-error"
exit 1
