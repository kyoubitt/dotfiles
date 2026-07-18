#!/bin/bash
mkdir -p ~/.local/state
grim -t jpeg ~/.local/state/lockscreen-raw.jpg
vips gaussblur "$HOME/.local/state/lockscreen-raw.jpg[shrink=4]" ~/.local/state/lockscreen.jpg 4 2>/dev/null
gtklock -b ~/.local/state/lockscreen.jpg
