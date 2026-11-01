import QtQuick
import qs.services

BarPill {
    id: root
    visible: Battery.available

    BarIcon {
        name: Battery.isCharging ? "battery_charging_full" : Battery.isLow ? "battery_alert" : "battery_full"
        color: Battery.isCritical ? BarStyle.danger : Battery.isCharging ? BarStyle.accent : BarStyle.text
    }
    BarText { visible: !root.vertical; text: Math.round(Battery.percentage * 100) + "%" }
}
