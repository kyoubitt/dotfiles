pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Item {
    id: root

    readonly property color blobBg: ColorUtils.applyAlpha(SMColors.bg, 0.25)
    readonly property color pillBg: ColorUtils.applyAlpha(ColorUtils.mix(SMColors.fg, SMColors.bg, 0.2), 0.75)
    readonly property color textCol: SMColors.fg
    readonly property color dimCol: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.4)
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.5)

    // ResourceUsage auto-stops polling after 15s of inactivity - the bar is
    // always on screen, so just keep it alive for as long as the bar exists.
    Component.onCompleted: ResourceUsage.ensureRunning()

    component Blob: Rectangle {
        id: blob
        radius: height / 2
        antialiasing: true
        color: root.blobBg
        implicitHeight: 30

        default property alias content: blobRow.children
        property alias spacing: blobRow.spacing
        implicitWidth: blobRow.implicitWidth + 20

        RowLayout {
            id: blobRow
            anchors.centerIn: parent
            spacing: 8
        }
    }

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 16
        color: root.dimCol
    }

    component PillIcon: Text {
        font.family: "Material Symbols Rounded"
        font.pixelSize: 13
        color: root.textCol
        Layout.alignment: Qt.AlignVCenter
    }

    component PillText: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: root.textCol
        Layout.alignment: Qt.AlignVCenter
    }

    // Left: workspaces
    Blob {
        id: wsBlob
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: NiriService.currentOutputWorkspaces
            delegate: Rectangle {
                id: wsButton
                required property var modelData
                readonly property bool active: modelData.id == NiriService.focusedWorkspaceId
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 22
                implicitHeight: 22
                radius: height / 2
                antialiasing: true
                color: active ? SMColors.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: wsButton.modelData.idx
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: wsButton.active ? SMColors.bg : root.dimTextCol
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.switchToWorkspace(wsButton.modelData.idx)
                }
            }
        }
    }


    // Center cluster: date | media (pill) | volume | weather
    // Whole cluster opens the control center - it holds the full media
    // controls, volume slider, and calendar these pills are previews of.
    Blob {
        id: centerBlob
        anchors.centerIn: parent
        spacing: 8

        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.mediaWidgetOpen = !GlobalStates.mediaWidgetOpen
        }

        PillText {
            text: Qt.locale().toString(DateTime.clock.date, "ddd, MMM d")

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: GlobalStates.calendarWidgetOpen = !GlobalStates.calendarWidgetOpen
            }
        }

        Divider {}

        Rectangle {
            visible: MprisController.activePlayer !== null
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            antialiasing: true
            color: root.pillBg
            implicitWidth: mediaRow.implicitWidth + 16
            implicitHeight: 22

            RowLayout {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 5
                PillIcon { text: "music_note" }
                MarqueeText {
                    Layout.preferredWidth: 180
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: root.textCol
                    text: MprisController.activeTrack?.title
                        ? `${MprisController.activeTrack.title} — ${MprisController.activeTrack.artist}`
                        : ""
                }
            }
        }

        Divider {}

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            PillIcon { text: Audio.value > 0.5 ? "volume_up" : Audio.value > 0 ? "volume_down" : "volume_off" }
            PillText { text: Math.round((Audio.value ?? 0) * 100) + "%" }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: GlobalStates.soundWidgetOpen = !GlobalStates.soundWidgetOpen
            }
        }

        PillIcon { visible: Weather.enabled && Weather.data.temp !== "--°C"; text: "clear_day" }
        PillText { visible: Weather.enabled && Weather.data.temp !== "--°C"; text: Weather.data.temp }
    }

    // System stats - display-only, separate from the date/media/sound blob
    // above so it never triggers a popup on click.
    Blob {
        anchors.left: centerBlob.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        PillIcon { text: "memory" }
        PillText { text: Math.round((ResourceUsage.cpuUsage ?? 0) * 100) + "%" }

        Divider {}

        PillIcon { text: "device_thermostat" }
        PillText { text: (ResourceUsage.cpuTemp ?? 0) + "°C" }

        Divider {}

        PillIcon { text: "sd_card" }
        PillText { text: Math.round((ResourceUsage.memoryUsedPercentage ?? 0) * 100) + "%" }
    }

    // Right: taskbar | tray | clock
    Blob {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Every currently open window, grouped by app
        Repeater {
            id: taskbarRepeater
            model: TaskbarApps.apps.filter(app => app.toplevels.length > 0)
            delegate: Rectangle {
                id: taskBtn
                required property var modelData
                readonly property var toplevels: taskBtn.modelData.toplevels
                readonly property bool active: taskBtn.toplevels.some(t => t.activated)
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 24
                implicitHeight: 24
                radius: 7
                antialiasing: true
                color: taskBtn.active ? ColorUtils.applyAlpha(SMColors.accent, 0.25) : "transparent"

                Image {
                    anchors.centerIn: parent
                    sourceSize.width: 16
                    sourceSize.height: 16
                    source: Quickshell.iconPath(AppSearch.guessIcon(taskBtn.modelData.appId), "image-missing")
                }

                Rectangle {
                    visible: taskBtn.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    width: 4
                    height: 2
                    radius: 1
                    antialiasing: true
                    color: SMColors.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const tls = taskBtn.toplevels
                        if (tls.length === 0) return
                        const focused = tls.find(t => t.activated)
                        if (focused && tls.length > 1) {
                            tls[(tls.indexOf(focused) + 1) % tls.length].activate()
                        } else {
                            tls[0].activate()
                        }
                    }
                }
            }
        }

        Divider { visible: taskbarRepeater.count > 0 }

        Repeater {
            id: trayRepeater
            // Vesktop (and similar Electron chat apps) register a tray icon
            // on top of their normal window, which just duplicates the entry
            // already shown in the taskbar above - hide it here.
            model: [...TrayService.pinnedItems, ...TrayService.unpinnedItems].filter(item => {
                const id = (item.id ?? "").toLowerCase()
                const title = (item.title ?? "").toLowerCase()
                const tooltip = (item.tooltipTitle ?? "").toLowerCase()
                return !id.includes("vesktop") && !title.includes("vesktop") && !tooltip.includes("vesktop")
            })
            delegate: Image {
                id: trayIcon
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                source: trayIcon.modelData.icon
                sourceSize: Qt.size(12, 12)
                width: 12
                height: 12
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            // Some apps (Vesktop/Discord etc.) don't implement the
                            // tray Activate DBus call properly, so plain activate()
                            // silently does nothing - smartToggle works around that.
                            if (!TrayService.smartToggle(trayIcon.modelData)) trayIcon.modelData.activate()
                        } else {
                            trayIcon.modelData.display(null, 0, 0)
                        }
                    }
                }
            }
        }

        Divider { visible: trayRepeater.count > 0 }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: clockText.implicitWidth
            implicitHeight: clockText.implicitHeight

            PillText {
                id: clockText
                text: Qt.locale().toString(DateTime.clock.date, "hh:mm:ss AP")
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen
            }
        }
    }
}
