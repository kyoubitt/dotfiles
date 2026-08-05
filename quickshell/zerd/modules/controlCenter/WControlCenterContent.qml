pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Item {
    id: root

    signal closed()
    function close() { root.closed() }

    readonly property color cardBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.1)
    readonly property color toggleOnBg: SMColors.accent
    readonly property color toggleOffBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.14)
    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.6)

    implicitWidth: 280
    implicitHeight: mainCol.implicitHeight + 16

    // Network.wifiEnabled/toggleWifi() go through nmcli, but this system
    // doesn't run NetworkManager - use rfkill directly instead, same as
    // the rest of this setup does for wifi/bluetooth.
    property bool wifiRadioEnabled: true
    function refreshWifiState() {
        wifiCheckProc.running = false
        wifiCheckProc.running = true
    }
    Component.onCompleted: refreshWifiState()

    property list<real> visualizerPoints: []
    Process {
        id: cavaProc
        running: MprisController.isPlaying
        onRunningChanged: { if (!running) root.visualizerPoints = [] }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/media_widget_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }

    Process {
        id: wifiCheckProc
        command: ["rfkill", "list", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiRadioEnabled = !text.includes("Soft blocked: yes")
            }
        }
    }

    Process {
        id: wifiToggleProc
        command: ["rfkill", "toggle", "wifi"]
        onExited: root.refreshWifiState()
    }

    // MPRIS position doesn't update reactively on its own while playing.
    Timer {
        running: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: MprisController.activePlayer?.positionChanged()
    }

    Rectangle {
        anchors.fill: parent
        color: SMColors.bg
        radius: 14
        antialiasing: true
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.1)
    }

    component SectionCard: Rectangle {
        radius: 12
        antialiasing: true
        color: root.cardBg
        Layout.fillWidth: true
    }

    component IconText: Text {
        font.family: "Material Symbols Rounded"
        color: root.textCol
        Layout.alignment: Qt.AlignVCenter
    }

    component CCSlider: Item {
        id: slider
        required property string icon
        property real value: 0
        signal moved(real value)
        Layout.fillWidth: true
        implicitHeight: 18

        RowLayout {
            anchors.fill: parent
            spacing: 8
            IconText { text: slider.icon; font.pixelSize: 15 }
            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 5
                radius: height / 2
                antialiasing: true
                color: root.toggleOffBg

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(1, slider.value))
                    radius: height / 2
                    antialiasing: true
                    color: SMColors.accent
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => slider.moved(Math.max(0, Math.min(1, mouse.x / track.width)))
                    onPositionChanged: mouse => {
                        if (pressed) slider.moved(Math.max(0, Math.min(1, mouse.x / track.width)))
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }
        spacing: 8

        // Media card
        SectionCard {
            visible: MprisController.activePlayer !== null
            implicitHeight: mediaCol.implicitHeight + 20

            ColumnLayout {
                id: mediaCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        implicitWidth: 60
                        implicitHeight: 60
                        radius: 10
                        antialiasing: true
                        color: root.toggleOffBg
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: MprisController.activeTrack?.artUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            sourceSize: Qt.size(width * 2, height * 2)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        MarqueeText {
                            Layout.fillWidth: true
                            font.pixelSize: 13
                            font.bold: true
                            color: root.textCol
                            text: MprisController.activeTrack?.title ?? ""
                        }
                        MarqueeText {
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: root.dimTextCol
                            text: MprisController.activeTrack?.artist ?? ""
                        }
                    }
                }

                WavySeekbar {
                    Layout.fillWidth: true
                    implicitHeight: 12
                    amplitude: 3
                    progress: {
                        const p = MprisController.activePlayer
                        return (p && p.length > 0) ? Math.max(0, Math.min(1, p.position / p.length)) : 0
                    }
                    accentColor: SMColors.accent
                    dimColor: root.dimTextCol
                    animate: MprisController.isPlaying
                    onSeekRequested: fraction => {
                        const p = MprisController.activePlayer
                        if (!p || p.length <= 0) return
                        p.position = fraction * p.length
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Layout.alignment: Qt.AlignHCenter

                    IconText {
                        text: "skip_previous"
                        font.pixelSize: 18
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
                    }
                    IconText {
                        text: MprisController.isPlaying ? "pause" : "play_arrow"
                        font.pixelSize: 20
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
                    }
                    IconText {
                        text: "skip_next"
                        font.pixelSize: 18
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.next() }
                    }
                }

                // Small equalizer, same cava data the media widget/session
                // screen use.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    spacing: 3

                    Repeater {
                        model: 24
                        delegate: Rectangle {
                            id: eqBar
                            required property int index
                            readonly property real level: root.visualizerPoints.length > 0
                                ? Math.max(0, Math.min(1, (root.visualizerPoints[Math.min(eqBar.index, root.visualizerPoints.length - 1)] ?? 0) / 1000))
                                : 0
                            Layout.alignment: Qt.AlignBottom
                            implicitWidth: 3
                            implicitHeight: 3 + level * 14
                            radius: width / 2
                            antialiasing: true
                            color: SMColors.accent
                            opacity: 0.5 + level * 0.5

                            Behavior on implicitHeight { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            Behavior on opacity { NumberAnimation { duration: 90 } }
                        }
                    }
                }
            }
        }

        // Toggle grid
        SectionCard {
            implicitHeight: toggleGrid.implicitHeight + 16

            GridLayout {
                id: toggleGrid
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                component ToggleButton: Rectangle {
                    id: btn
                    required property string icon
                    required property string label
                    required property bool on
                    signal clicked()
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 10
                    antialiasing: true
                    color: btn.on ? root.toggleOnBg : root.toggleOffBg

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            text: btn.icon
                            font.pixelSize: 15
                            color: btn.on ? SMColors.bg : root.textCol
                        }
                        Text {
                            text: btn.label
                            font.pixelSize: 11
                            color: btn.on ? SMColors.bg : root.textCol
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.clicked()
                    }
                }

                ToggleButton {
                    icon: "wifi"
                    label: "Wi-Fi"
                    on: root.wifiRadioEnabled
                    onClicked: wifiToggleProc.running = true
                }
                ToggleButton {
                    icon: "bluetooth"
                    label: "Bluetooth"
                    on: BluetoothStatus.enabled
                    onClicked: {
                        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }
                ToggleButton {
                    icon: Audio.source?.audio?.muted ? "mic_off" : "mic"
                    label: "Mic"
                    on: !(Audio.source?.audio?.muted ?? true)
                    onClicked: Audio.toggleMicMute()
                }
                ToggleButton {
                    icon: "graphic_eq"
                    label: "EasyEffects"
                    on: EasyEffects.active
                    onClicked: EasyEffects.toggle()
                }
            }
        }

        // Sliders
        SectionCard {
            implicitHeight: sliderCol.implicitHeight + 16

            ColumnLayout {
                id: sliderCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 10

                CCSlider {
                    icon: "brightness_6"
                    value: Brightness.monitors[0]?.brightness ?? 0
                    onMoved: v => { if (Brightness.monitors[0]) Brightness.monitors[0].setBrightness(v) }
                }
                CCSlider {
                    icon: Audio.value > 0.5 ? "volume_up" : Audio.value > 0 ? "volume_down" : "volume_off"
                    value: Audio.value
                    onMoved: v => { if (Audio.sink) Audio.sink.audio.volume = v }
                }
            }
        }

        // Battery
        SectionCard {
            visible: Battery.available
            implicitHeight: 36

            RowLayout {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                IconText { text: "battery_full"; font.pixelSize: 15 }
                Text {
                    Layout.fillWidth: true
                    text: Math.round(Battery.percentage * 100) + "%"
                    color: root.textCol
                    font.pixelSize: 12
                }
            }
        }

        // Notifications
        SectionCard {
            implicitHeight: notifCol.implicitHeight + 16

            ColumnLayout {
                id: notifCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: `Notifications (${Notifications.list.length})`
                        color: root.textCol
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        visible: Notifications.list.length > 0
                        text: "Clear all"
                        color: SMColors.accent
                        font.pixelSize: 11
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.discardAllNotifications() }
                    }
                }

                Text {
                    visible: Notifications.list.length === 0
                    text: "No notifications"
                    color: root.dimTextCol
                    font.pixelSize: 11
                }

                Repeater {
                    model: Notifications.list.slice(0, 3)
                    delegate: Rectangle {
                        id: notifItem
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: notifItemCol.implicitHeight + 10
                        radius: 6
                        antialiasing: true
                        color: root.toggleOffBg

                        ColumnLayout {
                            id: notifItemCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: notifItem.modelData?.summary ?? ""
                                color: root.textCol
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                text: notifItem.modelData?.body ?? ""
                                color: root.dimTextCol
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && Notifications.list.length > 0) {
            Notifications.discardAllNotifications()
            event.accepted = true
        }
    }
}
