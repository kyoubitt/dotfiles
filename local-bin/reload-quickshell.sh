#!/usr/bin/env bash
# Restarts the quickshell "zerd" shell and reports success/failure via a
# notification (rendered by zerd's own notification popup, which owns the
# system notification DBus service - see services/ConflictKiller.qml).

QS_CONFIG="zerd"
LOG="$HOME/.cache/quickshell-zerd.log"
QMLCACHE="$HOME/.cache/quickshell/qmlcache"

pkill -f "qs -c $QS_CONFIG"

for _ in $(seq 1 20); do
    pgrep -f "^qs -c $QS_CONFIG\$" >/dev/null 2>&1 || break
    sleep 0.1
done

# Quickshell's compiled-QML cache can serve a stale version of an edited
# file after a kill+relaunch instead of actually recompiling it - clear it
# every time so a reload is a real reload, not maybe-a-reload. The relaunch
# below also disables the cache outright (QML_DISABLE_DISK_CACHE, matching
# niri/scripts/startup.sh) so this is belt-and-suspenders, not load-bearing.
rm -rf "${QMLCACHE:?}"/*

# Render the shell on Mesa (the AMD iGPU) so the NVIDIA stack is not loaded for a bar
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json __GLX_VENDOR_LIBRARY_NAME=mesa QML_DISABLE_DISK_CACHE=1 nohup qs -c "$QS_CONFIG" > "$LOG" 2>&1 &
disown

for _ in $(seq 1 30); do
    if pgrep -f "^qs -c $QS_CONFIG\$" >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.1
done

notify-send "Quickshell reload failed" -a "Shell" -u critical -i "dialog-error"
exit 1
