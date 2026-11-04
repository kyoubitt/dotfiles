import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// Small tools: region screenshot, screen recording, colour picker, clipboard
// history, caffeine (blocks idle/sleep) and night light. Each is a plain icon
// button; recording, caffeine and night light light up while running.
BarPill {
    id: root

    component Tool: Item {
        id: tool
        property string icon
        property bool lit: false
        property string tip: ""
        signal tapped()
        implicitWidth: 28
        implicitHeight: 28
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: tool.lit ? BarStyle.accent : (areaHover.hovered ? BarStyle.plateHover : "transparent")
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        BarIcon {
            anchors.centerIn: parent
            name: tool.icon; size: 18
            fill: tool.lit ? 1 : 0
            color: tool.lit ? BarStyle.onAccent : (areaHover.hovered ? BarStyle.text : BarStyle.subtext)
            Behavior on color { ColorAnimation { duration: 110 } }
        }
        MouseArea { id: area; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tool.tapped() }
        HoverHandler { id: areaHover }
        BarTip { text: tool.tip }
    }
    component Divider: Rectangle { width: 1; height: 14; color: BarStyle.border }

    Tool { tip: "Screenshot"; icon: "screenshot_region"; onTapped: Quickshell.execDetached(["niri", "msg", "action", "screenshot"]) }
    Tool { tip: BarTools.recording ? "Stop recording  " + BarTools.clock(BarTools.recordSeconds) : "Record screen (saved to OBS Recordings)"; icon: BarTools.recording ? "stop_circle" : "screen_record"; lit: BarTools.recording; onTapped: BarTools.toggleRecording() }
    Tool { tip: "Colour picker"; icon: "colorize"; onTapped: Quickshell.execDetached(["hyprpicker", "-a"]) }
    Divider {}
    Tool { tip: "Clipboard"; icon: "content_paste"; onTapped: root.openPopup("clipboard") }
    Divider {}
    Tool { tip: BarTools.caffeine ? "Caffeine on" : "Caffeine"; icon: "coffee"; lit: BarTools.caffeine; onTapped: BarTools.toggleCaffeine() }
    Tool { tip: BarTools.nightLight ? "Night light on (click to turn off)" : "Night light"; icon: "bedtime"; lit: BarTools.nightLight; onTapped: BarTools.toggleNightLight() }
}
