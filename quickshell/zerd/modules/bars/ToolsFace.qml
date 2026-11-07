import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

// Small tools: region screenshot, screen recording, colour picker, clipboard
// history, caffeine (blocks idle/sleep) and night light. Round buttons in one capsule
// sharing a liquid hover; recording, caffeine and night light fill while running.
BarPill {
    id: root
    strip: true

    component Tool: BarCell {
        id: tool
        property string icon
        property bool lit: false
        property color litFill: BarStyle.accent
        property color litInk: BarStyle.onAccent
        fill: lit ? litFill : "transparent"
        BarIcon {
            name: tool.icon; size: BarStyle.iconSize
            fill: tool.lit ? 1 : 0
            color: tool.lit ? tool.litInk : (tool.hovered ? BarStyle.text : BarStyle.subtext)
            Behavior on color { ColorAnimation { duration: 110 } }
        }
    }
    component Divider: Item {
        width: 7; height: 14
        Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: BarStyle.border }
    }

    Tool { tip: "Screenshot"; icon: "screenshot_region"; onTapped: Quickshell.execDetached(["niri", "msg", "action", "screenshot"]) }
    Tool {
        tip: BarTools.recording ? "Stop recording  " + BarTools.clock(BarTools.recordSeconds) : "Record screen (saved to OBS Recordings)"
        icon: BarTools.recording ? "stop_circle" : "screen_record"
        lit: BarTools.recording; litFill: BarStyle.danger; litInk: Appearance.colors.colOnError
        onTapped: BarTools.toggleRecording()
    }
    Tool { tip: "Colour picker"; icon: "colorize"; onTapped: Quickshell.execDetached(["hyprpicker", "-a"]) }
    Divider {}
    Tool { tip: "Clipboard"; icon: "content_paste"; onTapped: root.openPopup("clipboard") }
    Divider {}
    Tool { tip: BarTools.caffeine ? "Caffeine on" : "Caffeine"; icon: "coffee"; lit: BarTools.caffeine; onTapped: BarTools.toggleCaffeine() }
    Tool { tip: BarTools.nightLight ? "Night light on (click to turn off)" : "Night light"; icon: "bedtime"; lit: BarTools.nightLight; onTapped: BarTools.toggleNightLight() }
}
