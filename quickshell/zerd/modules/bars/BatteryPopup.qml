import QtQuick
import Quickshell.Services.UPower
import qs.services

// Charge, what it is doing, time left, draw, and the power profile.
Column {
    id: root

    readonly property real pct: Battery.percentage
    readonly property bool charging: Battery.isCharging
    readonly property string state: Battery.isFullAndCharging || (Battery.isFull && Battery.isPluggedIn) ? "Full"
        : charging ? "Charging" : Battery.isPluggedIn ? "Plugged in" : "On battery"
    readonly property real seconds: charging ? Battery.timeToFull : Battery.timeToEmpty
    readonly property color tone: Battery.isCritical ? BarStyle.danger : Battery.isLow && !charging ? "#f0b35a" : BarStyle.accent
    spacing: 14
    width: 300

    function span(sec: real): string {
        if (!(sec > 0)) return ""
        const m = Math.round(sec / 60)
        return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min"
    }

    Row {
        spacing: 16
        BarRing {
            diameter: 84
            value: root.pct
            tint: root.tone
            icon: root.charging ? "bolt" : "battery_full"
            text: Math.round(root.pct * 100) + "%"
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            BarText { text: root.state; font.pixelSize: 16; font.weight: Font.DemiBold }
            BarText {
                visible: root.span(root.seconds).length > 0
                text: root.span(root.seconds) + (root.charging ? " until full" : " remaining")
                color: BarStyle.subtext
            }
            BarText {
                visible: Battery.energyRate > 0
                text: Battery.energyRate.toFixed(1) + " W " + (root.charging ? "in" : "draw")
                color: BarStyle.subtext
                font.pixelSize: 12
            }
        }
    }

    Column {
        spacing: 6
        BarText { text: "Power profile"; font.pixelSize: 11; color: BarStyle.subtext }
        Row {
            spacing: 6
            Repeater {
                model: [
                    { name: "Saver", icon: "eco", profile: PowerProfile.PowerSaver },
                    { name: "Balanced", icon: "balance", profile: PowerProfile.Balanced },
                    { name: "Performance", icon: "bolt", profile: PowerProfile.Performance, needs: PowerProfiles.hasPerformanceProfile }
                ].filter(p => p.needs !== false)
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: PowerProfiles.profile === modelData.profile
                    width: (300 - 12) / 3; height: 56; radius: 16
                    color: on ? BarStyle.accent : BarStyle.plateHover
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: parent.parent.modelData.icon; size: 18; fill: 1; color: parent.parent.on ? BarStyle.onAccent : BarStyle.subtext }
                        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.name; font.pixelSize: 11; color: parent.parent.on ? BarStyle.onAccent : BarStyle.text }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = parent.modelData.profile }
                }
            }
        }
    }

    Row {
        visible: UPower.displayDevice.healthPercentage > 0
        spacing: 6
        BarIcon { name: "health_and_safety"; size: 16; color: BarStyle.subtext }
        BarText { text: "Battery health " + Math.round(UPower.displayDevice.healthPercentage) + "%"; font.pixelSize: 12; color: BarStyle.subtext }
    }
}
