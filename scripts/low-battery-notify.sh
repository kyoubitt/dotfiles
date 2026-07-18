#!/bin/bash
notified_20=0
notified_10=0
notified_5=0

while true; do
  battery_status=$(acpi -b | grep -o 'Discharging\|Charging')
  battery_level=$(acpi -b | grep -P -o '[0-9]+(?=%)')

  if [ "$battery_status" = "Discharging" ]; then
    if [ "$battery_level" -eq 20 ] && [ "$notified_20" -eq 0 ]; then
      notify-send -u critical "Battery 20%" "Connect charger"
      notified_20=1
    fi

    if [ "$battery_level" -eq 10 ] && [ "$notified_10" -eq 0 ]; then
      notify-send -u critical "Battery 10%" "Connect charger now"
      notified_10=1
    fi

    if [ "$battery_level" -eq 5 ] && [ "$notified_5" -eq 0 ]; then
      notify-send -u critical "Battery 5%" "System will shutdown"
      notified_5=1
    fi
  fi

  if [ "$battery_status" = "Charging" ] || [ "$battery_level" -gt 21 ]; then
    notified_20=0
    notified_10=0
    notified_5=0
  fi

  sleep 60
done
