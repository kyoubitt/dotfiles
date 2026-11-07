import QtQuick
import Quickshell.Io
import qs.services

// Big time with seconds, the date, how far through the day it is, other time zones, and the calendar.
Column {
    id: root

    property date now: new Date()
    spacing: 14
    width: 320
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

    // Other zones come from `date` itself: the JS engine here ignores timeZone options.
    readonly property var zones: WorldClock.timezones.slice(0, 3)
    property var zoneInfo: ({})
    Process {
        id: zoneProbe
        command: ["sh", "-c", "for z in \"$@\"; do echo \"$z|$(TZ=$z date '+%H:%M|%Y%m%d')\"; done", "sh"].concat(root.zones)
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {}
                for (const l of text.split("\n")) {
                    const p = l.split("|")
                    if (p.length >= 3) out[p[0]] = { time: p[1], day: p[2] }
                }
                root.zoneInfo = out
            }
        }
    }
    Component.onCompleted: zoneProbe.running = true
    Timer { interval: 20000; repeat: true; running: true; onTriggered: zoneProbe.running = true }
    function zoneTime(tz: string): string { return root.zoneInfo[tz]?.time ?? "--:--" }
    function zoneDay(tz: string): string {
        const d = root.zoneInfo[tz]?.day
        if (!d) return ""
        const mine = Qt.formatDate(root.now, "yyyyMMdd")
        return d === mine ? "today" : d > mine ? "tomorrow" : "yesterday"
    }
    readonly property real dayProgress: (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400

    Column {
        spacing: 2
        Row {
            spacing: 6
            BarText { text: Qt.formatTime(root.now, "hh:mm"); font.pixelSize: 40; font.weight: Font.DemiBold; lineHeight: 48 }
            BarText { y: 20; text: Qt.formatTime(root.now, "ss"); font.pixelSize: 18; color: BarStyle.accent; font.weight: Font.DemiBold }
        }
        BarText { text: Qt.formatDate(root.now, "dddd, d MMMM yyyy"); color: BarStyle.subtext }
    }

    BarCard {
        width: parent.width
        Column {
            spacing: 6
            width: parent.width
            Rectangle {
                width: parent.width; height: 8; radius: 4; color: BarStyle.cardHigh
                Rectangle { width: Math.max(8, parent.width * root.dayProgress); height: 8; radius: 4; color: BarStyle.accent }
            }
            BarText { text: Math.round(root.dayProgress * 100) + "% of the day gone"; font.pixelSize: 12; color: BarStyle.subtext }
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: WorldClock.timezones.length > 0
        Repeater {
            model: root.zones
            delegate: Item {
                required property string modelData
                width: 320; height: 28
                BarText { anchors.verticalCenter: parent.verticalCenter; text: WorldClock.labelFor(modelData); width: 170; elide: Text.ElideRight; font.pixelSize: 12 }
                BarText { anchors.verticalCenter: parent.verticalCenter; x: 170; text: root.zoneDay(modelData); font.pixelSize: 11; color: BarStyle.subtext; width: 60 }
                BarText { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; text: root.zoneTime(modelData); font.weight: Font.DemiBold }
            }
        }
    }

}
