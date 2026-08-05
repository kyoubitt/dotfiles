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

    // Higher alpha than before - at 0.25 the pills let strongly-colored
    // wallpaper/window content bleed through and wash out the text on top.
    readonly property color blobBg: ColorUtils.applyAlpha(SMColors.bg, 0.6)
    readonly property color pillBg: ColorUtils.applyAlpha(ColorUtils.mix(SMColors.fg, SMColors.bg, 0.2), 0.85)
    readonly property color textCol: SMColors.fg
    readonly property color dimCol: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.4)
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.75)

    component Blob: Rectangle {
        id: blob
        radius: height / 2
        antialiasing: true
        color: blob.clickable && blob.hovered
            ? ColorUtils.applyAlpha(ColorUtils.mix(root.blobBg, SMColors.fg, 0.12), 1)
            : root.blobBg
        Behavior on color { ColorAnimation { duration: 100 } }
        implicitHeight: 36

        default property alias content: blobRow.children
        property alias spacing: blobRow.spacing
        // Whole-blob click handling lives here as a direct sibling of blobRow
        // (not inside it) so it's a plain Item under a non-Layout parent -
        // putting a MouseArea inside a RowLayout with anchors.fill triggers
        // "anchors on an item managed by a layout" (undefined behavior).
        property bool clickable: false
        property bool hovered: false
        signal blobClicked()
        implicitWidth: blobRow.implicitWidth + 24

        MouseArea {
            anchors.fill: parent
            z: -1
            visible: blob.clickable
            enabled: blob.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: blob.hovered = true
            onExited: blob.hovered = false
            onClicked: blob.blobClicked()
        }

        RowLayout {
            id: blobRow
            anchors.centerIn: parent
            spacing: 8
        }
    }

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 14
        color: ColorUtils.applyAlpha(SMColors.fg, 0.15)
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
                property bool hovered: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 22
                implicitHeight: 22
                radius: height / 2
                antialiasing: true
                color: active ? SMColors.accent
                    : hovered ? ColorUtils.applyAlpha(SMColors.fg, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

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
                    hoverEnabled: true
                    onEntered: wsButton.hovered = true
                    onExited: wsButton.hovered = false
                    onClicked: NiriService.switchToWorkspace(wsButton.modelData.idx)
                }
            }
        }
    }


    // Center cluster: date | media (pill) | volume | weather
    // Whole cluster opens the control center - it holds the full media
    // controls, volume slider, and calendar these pills are previews of.
    //
    // Centered on the screen/bar itself, not in the gap between the
    // workspace pill and right-side clusters - gap-centering looked
    // "centered" mathematically but visibly drifted off true center
    // whenever the taskbar/tray group was a different width than the
    // workspace pill, which is most of the time.
    // Each interactive piece here is its own self-contained hoverable pill
    // (own MouseArea, own highlight) rather than one MouseArea spanning the
    // whole blob - that whole-blob-click approach made date/volume clicks
    // unreliable (an ancestor MouseArea competing with them for the same
    // area) and highlighted the entire cluster on hover instead of just
    // whichever piece the pointer was actually over.
    component HoverPill: Rectangle {
        id: hoverPill
        default property alias content: pillRow.children
        property alias spacing: pillRow.spacing
        property bool clickable: true
        property bool hovered: false
        signal pillClicked()

        Layout.alignment: Qt.AlignVCenter
        radius: height / 2
        antialiasing: true
        implicitHeight: 24
        implicitWidth: pillRow.implicitWidth + 12
        color: hoverPill.clickable && hoverPill.hovered
            ? ColorUtils.applyAlpha(SMColors.fg, 0.12)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 5
        }

        MouseArea {
            anchors.fill: parent
            visible: hoverPill.clickable
            enabled: hoverPill.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: hoverPill.hovered = true
            onExited: hoverPill.hovered = false
            onClicked: hoverPill.pillClicked()
        }
    }

    Blob {
        id: centerBlob
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        HoverPill {
            onPillClicked: GlobalStates.calendarWidgetOpen = !GlobalStates.calendarWidgetOpen
            PillText { text: Qt.locale().toString(DateTime.clock.date, "ddd, MMM d") }
        }

        Divider {}

        HoverPill {
            clickable: MprisController.activePlayer !== null
            opacity: MprisController.activePlayer !== null ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: 150 } }
            onPillClicked: GlobalStates.mediaWidgetOpen = !GlobalStates.mediaWidgetOpen
            PillIcon { text: MprisController.activePlayer !== null ? "music_note" : "music_off" }
            MarqueeText {
                Layout.preferredWidth: 180
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.textCol
                text: MprisController.activeTrack?.title
                    ? `${MprisController.activeTrack.title} — ${MprisController.activeTrack.artist}`
                    : "Nothing playing"
            }
        }

        Divider {}

        HoverPill {
            onPillClicked: GlobalStates.soundWidgetOpen = !GlobalStates.soundWidgetOpen
            PillIcon { text: Audio.value > 0.5 ? "volume_up" : Audio.value > 0 ? "volume_down" : "volume_off" }
            PillText { text: Math.round((Audio.value ?? 0) * 100) + "%" }
        }

        PillIcon { visible: Weather.enabled && Weather.data.temp !== "--°C"; text: "clear_day" }
        PillText { visible: Weather.enabled && Weather.data.temp !== "--°C"; text: Weather.data.temp }
    }

    // Right: clock
    Blob {
        id: clockBlob
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

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

    // Tray
    Blob {
        id: trayBlob
        visible: trayRepeater.count > 0
        anchors.right: clockBlob.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Tray items to always hide from the bar, matched against id/title/tooltip
        readonly property var hiddenTrayItems: [
            "vesktop", // duplicates the entry already shown in the taskbar above
            "claude_status_icon", // Claude Code's own background status icon
            "steam", // Steam sitting in the background - not useful as a bar icon
        ]

        Repeater {
            id: trayRepeater
            model: [...TrayService.pinnedItems, ...TrayService.unpinnedItems].filter(item => {
                const id = (item.id ?? "").toLowerCase()
                const title = (item.title ?? "").toLowerCase()
                const tooltip = (item.tooltipTitle ?? "").toLowerCase()
                return !trayBlob.hiddenTrayItems.some(hidden => id.includes(hidden) || title.includes(hidden) || tooltip.includes(hidden))
            })
            delegate: Image {
                id: trayIcon
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                source: trayIcon.modelData.icon
                sourceSize: Qt.size(15, 15)
                width: 15
                height: 15
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
    }

    // Taskbar: every currently open window, grouped by app
    Blob {
        id: taskbarBlob
        visible: taskbarRepeater.count > 0
        anchors.right: trayBlob.visible ? trayBlob.left : clockBlob.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            id: taskbarRepeater
            model: TaskbarApps.apps

            delegate: Rectangle {
                id: taskBtn
                required property var modelData
                readonly property var toplevels: taskBtn.modelData.toplevels
                readonly property bool active: taskBtn.toplevels.some(t => t.activated)
                readonly property var desktopEntry: DesktopEntries.byId(taskBtn.modelData.appId) ?? DesktopEntries.heuristicLookup(taskBtn.modelData.appId)
                readonly property string displayName: taskBtn.desktopEntry?.name ?? taskBtn.modelData.appId
                property bool hovered: false
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 30
                implicitHeight: 30
                radius: 9
                antialiasing: true
                color: taskBtn.active ? ColorUtils.applyAlpha(SMColors.accent, 0.25)
                    : taskBtn.hovered ? ColorUtils.applyAlpha(SMColors.fg, 0.12)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Image {
                    anchors.centerIn: parent
                    sourceSize.width: 18
                    sourceSize.height: 18
                    source: AppSearch.getIconSource(taskBtn.modelData.appId, "image-missing")
                }

                // One segment per open window (capped), brighter for the focused one
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    spacing: 2
                    Repeater {
                        model: Math.min(taskBtn.toplevels.length, 3)
                        delegate: Rectangle {
                            required property int index
                            width: 5
                            height: 2
                            radius: 1
                            antialiasing: true
                            color: taskBtn.toplevels[index].activated ? SMColors.accent : root.dimCol
                        }
                    }
                }

                MouseArea {
                    id: taskBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    onEntered: taskBtn.hovered = true
                    onExited: taskBtn.hovered = false
                    onClicked: mouse => {
                        const tls = taskBtn.toplevels
                        if (mouse.button === Qt.RightButton) {
                            taskBtnMenu.active = true
                            return
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            const focused = tls.find(t => t.activated) ?? tls[0]
                            focused.close()
                            return
                        }
                        const focused = tls.find(t => t.activated)
                        if (focused && tls.length > 1) {
                            tls[(tls.indexOf(focused) + 1) % tls.length].activate()
                        } else {
                            tls[0].activate()
                        }
                    }
                }

                StyledToolTip {
                    text: taskBtn.toplevels.length > 1
                        ? `${taskBtn.displayName} (${taskBtn.toplevels.length})`
                        : (taskBtn.toplevels[0]?.title || taskBtn.displayName)
                }

                ContextMenu {
                    id: taskBtnMenu
                    anchorItem: taskBtn
                    popupAbove: false
                    model: [{
                        text: "Close",
                        iconName: "close",
                        action: () => {
                            const tls = taskBtn.toplevels
                            const focused = tls.find(t => t.activated) ?? tls[0]
                            focused.close()
                        }
                    }]
                }
            }
        }
    }
}
