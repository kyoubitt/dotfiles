#!/bin/sh
# Screenshot keys (region, screen, window). The shell listens on a FIFO, so a key press costs a few
# milliseconds instead of a whole `qs ipc` start; if the shell is not listening, fall back to IPC.
f="$XDG_RUNTIME_DIR/zerd-screenshot"
if [ -p "$f" ] && timeout 0.3 sh -c 'printf "%s\n" "$1" > "$2"' sh "$1" "$f"; then
    exit 0
fi
exec qs -c zerd ipc call screenshot "$1"
