#!/bin/sh
# One snapshot of the network, for the bar. iwd (iwctl) side plus ethernet from sysfs.
clean() { sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }
wl=$(iwctl device list 2>/dev/null | clean | awk '/station/ {print $1; exit}')
echo "WL|$wl"
if [ -n "$wl" ]; then
    echo "---SHOW"
    iwctl station "$wl" show 2>/dev/null | clean
    echo "---NETS"
    iwctl station "$wl" get-networks 2>/dev/null | clean
    echo "---POWER"
    iwctl device "$wl" show 2>/dev/null | clean | awk '{for (i = 1; i < NF; i++) if ($i == "Powered") { print $(i + 1); exit }}'
fi
echo "---KNOWN"
iwctl known-networks list 2>/dev/null | clean
echo "---ETH"
for d in /sys/class/net/e*; do
    [ -e "$d" ] || continue
    n=$(basename "$d")
    echo "$n|$(cat "$d/carrier" 2>/dev/null)|$(cat "$d/speed" 2>/dev/null)|$(ip -4 -br addr show "$n" 2>/dev/null | awk '{print $3}')"
done
