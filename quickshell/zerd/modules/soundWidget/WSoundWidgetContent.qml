pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu

Rectangle {
    id: root

    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.6)
    readonly property color trackBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.14)
    readonly property color rowBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.08)

    // "image-missing" is deliberately never a hit (AppSearch.iconExists
    // excludes it on purpose, to detect failure), but it was also the
    // fallback passed to Quickshell.iconPath below - the current icon
    // theme doesn't ship an icon by that literal name, so a node with no
    // real match (a bare "java" process, no desktop entry) resolved to
    // nothing and rendered as a blank gap instead of any icon at all.
    // application-x-executable is the generic icon used as a fallback
    // everywhere else in this codebase and reliably exists.
    function iconForNode(node) {
        if (!node) return ""
        let icon = AppSearch.guessIcon(node.properties?.["application.icon-name"] ?? "")
        if (AppSearch.iconExists(icon)) return Quickshell.iconPath(icon, "application-x-executable")
        icon = AppSearch.guessIcon(node.properties?.["node.name"] ?? "")
        return Quickshell.iconPath(icon, "application-x-executable")
    }

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    radius: 18
    antialiasing: true
    color: ColorUtils.applyAlpha(SMColors.bg, 0.7)
    border.width: 1
    border.color: ColorUtils.applyAlpha(SMColors.fg, 0.1)

    // App/device nodes need to be tracked for their bound audio properties
    // (volume/muted) to actually stay live and be writable.
    PwObjectTracker {
        objects: [...Audio.outputAppNodes, ...Audio.outputDevices].filter(n => n)
    }

    component IconText: Text {
        font.family: "Material Symbols Rounded"
        color: root.textCol
    }

    component ThinSlider: Item {
        id: slider
        property real value: 0
        property bool muted: false
        signal moved(real value)
        implicitHeight: 16

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            implicitHeight: 6
            radius: height / 2
            antialiasing: true
            color: root.trackBg
            opacity: slider.muted ? 0.4 : 1

            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, slider.value))
                radius: height / 2
                antialiasing: true
                color: SMColors.accent
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => slider.moved(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => {
                if (pressed) slider.moved(Math.max(0, Math.min(1, mouse.x / width)))
            }
        }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IconText { text: "volume_up"; font.pixelSize: 16 }
            Text {
                Layout.fillWidth: true
                text: "Sound"
                color: root.textCol
                font.pixelSize: 14
                font.bold: true
            }
        }

        // Master output
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: masterCol.implicitHeight + 16
            radius: 12
            antialiasing: true
            color: root.rowBg

            ColumnLayout {
                id: masterCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Audio.friendlyDeviceName(Audio.sink)
                        color: root.textCol
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: Math.round((Audio.value ?? 0) * 100) + "%"
                        color: root.dimTextCol
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    IconText {
                        text: (Audio.sink?.audio?.muted ?? false) ? "volume_off"
                            : Audio.value > 0.5 ? "volume_up" : Audio.value > 0 ? "volume_down" : "volume_mute"
                        font.pixelSize: 16
                        color: (Audio.sink?.audio?.muted ?? false) ? root.dimTextCol : SMColors.accent
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Audio.toggleMute()
                        }
                    }
                    ThinSlider {
                        Layout.fillWidth: true
                        value: Audio.value
                        muted: Audio.sink?.audio?.muted ?? false
                        onMoved: v => Audio.setSinkVolume(v, false)
                    }
                }
            }
        }

        // Output device switcher
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: Audio.outputDevices.length > 1

            Text { text: "Output device"; color: root.dimTextCol; font.pixelSize: 10 }

            Repeater {
                model: Audio.outputDevices
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property bool active: deviceRow.modelData === Audio.sink
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    antialiasing: true
                    color: deviceRow.active ? ColorUtils.applyAlpha(SMColors.accent, 0.2) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6
                        IconText {
                            text: deviceRow.active ? "check_circle" : "radio_button_unchecked"
                            font.pixelSize: 13
                            color: deviceRow.active ? SMColors.accent : root.dimTextCol
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Audio.friendlyDeviceName(deviceRow.modelData)
                            color: root.textCol
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.setDefaultSink(deviceRow.modelData)
                    }
                }
            }
        }

        // Per-app mixer
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Audio.outputAppNodes.length > 0

            Text { text: "Apps"; color: root.dimTextCol; font.pixelSize: 10 }

            Repeater {
                model: Audio.outputAppNodes
                delegate: RowLayout {
                    id: appRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        sourceSize: Qt.size(18, 18)
                        source: root.iconForNode(appRow.modelData)
                    }
                    Text {
                        Layout.preferredWidth: 80
                        elide: Text.ElideRight
                        text: Audio.appNodeDisplayName(appRow.modelData)
                        color: root.textCol
                        font.pixelSize: 11
                    }
                    IconText {
                        text: (appRow.modelData.audio?.muted ?? false) ? "volume_off" : "volume_up"
                        font.pixelSize: 14
                        color: (appRow.modelData.audio?.muted ?? false) ? root.dimTextCol : SMColors.accent
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (appRow.modelData.audio) appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                            }
                        }
                    }
                    ThinSlider {
                        Layout.fillWidth: true
                        value: appRow.modelData.audio?.volume ?? 0
                        muted: appRow.modelData.audio?.muted ?? false
                        onMoved: v => { if (appRow.modelData.audio) appRow.modelData.audio.volume = v }
                    }
                }
            }
        }
    }
}
