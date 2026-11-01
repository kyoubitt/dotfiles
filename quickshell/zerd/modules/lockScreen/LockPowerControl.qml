import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu

// Sleep / restart / shut down in one outlined capsule. A highlight disc
// slides between the slots as the pointer moves; the caption under the
// capsule follows the same slot. Restart and shut down need a second click:
// the disc fills with the accent colour and a ring counts down 3 seconds.
// Nothing resizes, so hover can't flicker.
Item {
    id: root

    readonly property int slot: 44
    readonly property int armMs: 3000

    readonly property var actions: [
        { icon: "dark_mode", label: "sleep", armed: "sleep", confirm: false },
        { icon: "restart_alt", label: "restart", armed: "click again to restart", confirm: true },
        { icon: "power_settings_new", label: "shut down", armed: "click again to shut down", confirm: true },
    ]

    function run(i) {
        if (i === 0) Quickshell.execDetached(["/usr/bin/systemctl", "suspend", "-i"])
        else if (i === 1) Session.reboot()
        else Session.poweroff()
    }

    property int hoverIndex: -1
    property int armedIndex: -1
    property int pressedIndex: -1
    readonly property int activeIndex: armedIndex >= 0 ? armedIndex : hoverIndex

    // Last slot shown, so the disc and caption fade out where they were.
    property int lastIndex: 0
    onActiveIndexChanged: if (activeIndex >= 0) lastIndex = activeIndex

    implicitWidth: slot * 3
    implicitHeight: slot + 30

    // 1 -> 0 over the arm window.
    property real ring: 0
    NumberAnimation on ring {
        id: ringAnim
        running: false
        from: 1
        to: 0
        duration: root.armMs
    }
    Timer {
        id: disarm
        interval: root.armMs
        onTriggered: root.armedIndex = -1
    }
    onArmedIndexChanged: {
        if (armedIndex >= 0) { ringAnim.restart(); disarm.restart() }
        else { ringAnim.stop(); disarm.stop(); ring = 0 }
    }

    // Capsule
    Rectangle {
        id: capsule
        width: root.slot * 3
        height: root.slot
        radius: height / 2
        antialiasing: true
        color: ColorUtils.applyAlpha("#000000", 0.3)
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.28)
    }

    // Highlight disc
    Item {
        id: disc
        x: root.lastIndex * root.slot + 2
        y: 2
        width: root.slot - 4
        height: root.slot - 4
        opacity: root.activeIndex >= 0 ? 1 : 0
        scale: root.pressedIndex >= 0 ? 0.92 : 1

        Behavior on x {
            enabled: disc.opacity > 0.01
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: root.armedIndex >= 0 ? SMColors.accent : ColorUtils.applyAlpha(SMColors.fg, 0.18)
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Shape {
            anchors.fill: parent
            visible: root.armedIndex >= 0
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                fillColor: "transparent"
                strokeColor: SMColors.bg
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 18; centerY: 18
                    radiusX: 14.5; radiusY: 14.5
                    startAngle: -90
                    sweepAngle: root.ring * 360
                }
            }
        }
    }

    // Slots: icons and hit areas
    Repeater {
        model: root.actions

        delegate: Item {
            id: slotItem
            required property int index
            required property var modelData

            x: index * root.slot
            width: root.slot
            height: root.slot

            LockIcon {
                anchors.centerIn: parent
                text: slotItem.modelData.icon
                iconSize: 20
                fill: root.armedIndex === slotItem.index ? 1 : 0
                color: root.armedIndex === slotItem.index ? SMColors.bg : SMColors.fg
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoverIndex = slotItem.index
                onExited: if (root.hoverIndex === slotItem.index) root.hoverIndex = -1
                onPressed: root.pressedIndex = slotItem.index
                onReleased: root.pressedIndex = -1
                onCanceled: root.pressedIndex = -1
                onClicked: {
                    if (slotItem.modelData.confirm && root.armedIndex !== slotItem.index) {
                        root.armedIndex = slotItem.index
                        return
                    }
                    root.armedIndex = -1
                    root.run(slotItem.index)
                }
            }
        }
    }

    // Caption, tracking the active slot
    LockText {
        id: caption
        readonly property var info: root.actions[root.lastIndex]
        text: root.armedIndex >= 0 ? info.armed : info.label
        font.pixelSize: 13
        font.weight: Font.Medium
        font.letterSpacing: 0.3
        y: root.slot + 10 + (root.activeIndex >= 0 ? 0 : -4)
        x: Math.round(root.lastIndex * root.slot + root.slot / 2 - width / 2)
        opacity: root.activeIndex >= 0 ? 0.9 : 0

        Behavior on x {
            enabled: caption.opacity > 0.01
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
}
