#!/bin/bash
# Mod+Q: ask the shell, which closes the focused window itself (after a confirm card if
# `closeConfirm.enabled` is on). Only when the shell cannot be reached does niri close it.
# One path or the other, never both, so a second window is never closed by accident.
if timeout 1 qs -c zerd ipc call closeConfirm trigger >/dev/null 2>&1; then
    exit 0
fi
exec niri msg action close-window
