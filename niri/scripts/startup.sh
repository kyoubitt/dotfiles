#!/bin/bash
# Start polkit agent
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Start awww daemon for wallpaper
awww-daemon &

# Restore last wallpaper
sleep 1 && awww img "$(cat ~/.cache/awww/last-wallpaper 2>/dev/null)" -t fade --transition-duration 2 --transition-fps 30 &

# Start quickshell (wallpaper selector, panels, etc.)
# MALLOC_*: fewer allocator arenas and earlier trimming, so the shell keeps less freed memory resident
# (about 50 MB less at start, and far fewer threads).
# QML_DISABLE_DISK_CACHE: Qt's on-disk compiled-QML cache
# (~/.cache/quickshell/qmlcache/) can serve stale bytecode after an edit,
# especially through quickshell's own in-process hot-reload-on-save (which
# builds a fresh QML engine per reload but doesn't clear this cache the way
# a full restart does) - disabling it entirely means every reload, auto or
# manual, always compiles fresh from the actual file on disk.
MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=65536 MALLOC_MMAP_THRESHOLD_=131072 __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json __GLX_VENDOR_LIBRARY_NAME=mesa QML_DISABLE_DISK_CACHE=1 qs -c zerd > ~/.cache/quickshell-zerd.log 2>&1 &
