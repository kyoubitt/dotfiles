import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu
import qs.modules.waffle.looks
import qs.services
import qs.modules.bars

Item {
    id: root
    
    property string title: ""
    property string message: ""
    property string icon: "info"
    property bool isError: false
    property int duration: 3000
    property string source: "system" // "quickshell" or "niri"
    // Wallust-synced, matching the notification card's own accent choice
    // (WNotificationGroup/WNotificationItem) rather than the old Material
    // pipeline's colPrimary, which read as washed-out/near-white.
    property color accentColor: WallustColors.cyan

    // This toast window's own absolute screen origin (fixed, set by
    // ToastManager.qml) - composed with this card's own position within
    // that window (via mapToItem) to align backdrop blur correctly even as
    // toasts stack/reorder.
    property real windowScreenX: 0
    property real windowScreenY: 0

    signal dismissed()
    signal copyRequested()

    property bool copied: false

    implicitWidth: card.width
    implicitHeight: card.height

    // A soft, growing hover-circle icon button - the same recipe as
    // DockFlatIcon/NotifIconButton, replacing RippleButton (shared with 8
    // other files, so not edited in place) for this toast's own buttons.
    component ToastIconButton: Item {
        id: iconBtn
        property int baseSize: 20
        property int hoverSize: 26
        readonly property bool hovered: mouse.containsMouse
        signal clicked()

        implicitWidth: hoverSize
        implicitHeight: hoverSize

        Rectangle {
            anchors.centerIn: parent
            width: iconBtn.hovered ? iconBtn.hoverSize : iconBtn.baseSize
            height: width
            radius: height / 2
            antialiasing: true
            color: iconBtn.hovered ? ColorUtils.applyAlpha(SMColors.fg, 0.12) : "transparent"
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
        }
    }

    Rectangle {
        id: card
        width: contentLayout.implicitWidth + 36
        height: contentLayout.implicitHeight + 24
        // Full stadium/pill shape (fully rounded ends), not just a
        // rounded-rect - the original GlassBackground-based card had this
        // via Appearance.rounding.normal; swapping to a plain Rectangle for
        // the frosted-glass recipe silently flattened it to 14px fixed.
        radius: 26
        antialiasing: true
        // Genuine background blur, not just a tinted fill - see
        // BlurredBackdrop's own comment.
        // The same tonal surface as the notification banners: the wallust base with a breath of the accent.
        readonly property color tone: root.isError ? WallustColors.red : SMColors.accent
        color: Qt.tint(SMColors.bg, Qt.rgba(tone.r, tone.g, tone.b, root.isError ? 0.16 : 0.08))
        border.width: 1
        border.color: root.isError ? WallustColors.red : ColorUtils.applyAlpha(SMColors.fg, 0.14)

        WRectangularShadow { target: card }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.dismissed()
        }
        
        RowLayout {
            id: contentLayout
            anchors.centerIn: parent
            anchors.leftMargin: 20
            spacing: 10
            
            // Icon in a tinted circle
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 36; implicitHeight: 36; radius: 18
                color: ColorUtils.applyAlpha(card.tone, 0.2)
                BarIcon { anchors.centerIn: parent; name: root.icon; fill: 1; size: 20; color: card.tone }
            }

            // Content
            ColumnLayout {
                spacing: 2
                Layout.maximumWidth: 400

                BarText {
                    text: root.title
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: SMColors.fg
                }

                Text {
                    visible: root.message !== ""
                    text: root.message.length > 100 ? root.message.substring(0, 100) + "..." : root.message
                    font.family: "Inter"
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: 350
                }
            }

            // Copy button (only for errors with message)
            ToastIconButton {
                visible: root.isError && root.message !== ""
                baseSize: 20
                hoverSize: 26
                onClicked: {
                    console.log("[Toast] Copying to clipboard:", root.message.substring(0, 50))
                    copyProcess.running = true
                    root.copied = true
                    copyResetTimer.restart()
                }

                Process {
                    id: copyProcess
                    command: ["wl-copy", root.message]
                }

                BarIcon { anchors.centerIn: parent; name: root.copied ? "check" : "content_copy"; size: 16; color: SMColors.fg }

                StyledToolTip {
                    text: root.copied ? "Copied!" : "Copy error"
                }
            }

            // Close button
            ToastIconButton {
                visible: mouseArea.containsMouse
                baseSize: 20
                hoverSize: 26
                onClicked: root.dismissed()
                BarIcon { anchors.centerIn: parent; name: "close"; size: 16; color: SMColors.fg }
            }
        }
        
        // Auto-dismiss, paused while hovered - the old progress bar under
        // the text is gone, this is just its timer.
        Timer {
            interval: root.duration
            running: !mouseArea.containsMouse
            onTriggered: root.dismissed()
        }
    }

    Timer {
        id: copyResetTimer
        interval: 2000
        onTriggered: root.copied = false
    }
}
