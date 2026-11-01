pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu

/**
 * Windows 11 style notification item with swipe-to-dismiss
 */
Item {
    id: root
    
    required property var notification
    property bool onlyNotification: false

    readonly property string notifImage: notification?.image ?? ""
    readonly property string notifSummary: notification?.summary ?? ""
    readonly property string notifBody: notification?.body ?? ""
    readonly property string notifAppName: notification?.appName ?? ""
    readonly property var notifActions: notification?.actions ?? []
    readonly property int notifId: notification?.notificationId ?? -1
    readonly property bool hasImage: notifImage !== ""
    readonly property bool hasActions: notifActions.length > 0
    readonly property bool isCritical: notification?.urgency === NotificationUrgency.Critical

    implicitHeight: contentItem.height
    clip: true

    function dismiss() {
        Notifications.discardNotification(notifId)
    }

    // A discarded notification's image provider handle (image://qsimage/
    // <id>/1) gets freed by the service immediately, but this delegate can
    // stay alive briefly for the list's remove transition - if the Image
    // element re-requests during that window it hits a torn-down handle
    // ("Requested image from unknown handle"). Gating on actual presence in
    // Notifications.list (not just `notification` staying non-null) closes
    // that window regardless of transition timing.
    readonly property bool notifStillAlive: Notifications.list.some(n => n.notificationId === root.notifId)

    // A frosted, hover-growing pill button - the same recipe as the dock's
    // GhostPill/DockFlatIcon (WSideDockContent.qml), replacing the flat
    // default-Qt WBorderedButton look. Scoped to this file rather than
    // edited in place on WButton/WBorderedButton, since those are shared
    // with the unrelated close-confirm dialog. No custom default property -
    // callers mix a visual icon/text with a non-visual WToolTip as
    // children, and a `list<Item>`-typed content alias rejects WToolTip
    // outright; Item's own default `data` property accepts both, so
    // children anchor themselves to `parent` directly instead.
    component NotifPillButton: Item {
        id: pillBtn
        property bool primary: false
        readonly property bool hovered: mouse.containsMouse
        signal clicked()

        implicitHeight: 32
        implicitWidth: 40

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            antialiasing: true
            color: pillBtn.primary
                ? ColorUtils.applyAlpha(WallustColors.cyan, pillBtn.hovered ? 0.45 : 0.35)
                : ColorUtils.applyAlpha(SMColors.fg, pillBtn.hovered ? 0.18 : 0.14)
            border.width: 1
            border.color: pillBtn.primary
                ? ColorUtils.applyAlpha(WallustColors.cyan, 0.6)
                : ColorUtils.applyAlpha(SMColors.fg, 0.35)
            Behavior on color { ColorAnimation { duration: 150 } }

            scale: mouse.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillBtn.clicked()
        }
    }

    // Swipe to dismiss
    DragManager {
        id: dragManager
        anchors.fill: parent
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.dismiss()
        }

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > 60) {
                root.dismiss()
            } else {
                dragManager.resetDrag()
            }
        }
    }

    Rectangle {
        id: contentItem
        width: parent.width
        height: col.height + 12
        x: dragManager.dragDiffX
        color: "transparent"
        radius: Looks.radius.medium
        
        // Subtle rotation during swipe for natural feel
        rotation: dragManager.dragDiffX * 0.02
        transformOrigin: Item.Bottom

        Behavior on x {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.spring
            }
        }
        Behavior on rotation {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.spring
            }
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 8

            // Summary with urgency indicator
            RowLayout {
                visible: !root.onlyNotification
                Layout.fillWidth: true
                spacing: 6

                // Critical indicator with pulse animation
                Rectangle {
                    visible: root.isCritical
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: WallustColors.red

                    SequentialAnimation on opacity {
                        running: root.isCritical && Looks.transition.enabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }

                WText {
                    Layout.fillWidth: true
                    text: root.notifSummary
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: root.isCritical ? WallustColors.red : SMColors.fg
                    elide: Text.ElideRight
                }
            }

            // Image - larger and better presented for a genuine wide
            // hero/preview image. Some apps (e.g. Claude Code) send their
            // own app icon through this same "image" hint instead - those
            // are near-square, so they get a small squircle avatar
            // treatment instead of being stretched edge-to-edge, which used
            // to zoom a small icon into an unrecognizable, banded-looking
            // sliver.
            Rectangle {
                id: imageBox
                // Set once, imperatively, from Image.onStatusChanged below -
                // not a live binding off imageContent.implicitWidth/Height.
                // Those two feed back into this box's own implicitWidth
                // (via fillMode, which this flag also drives), which made a
                // readonly-property version of this a genuine binding loop
                // ("Binding loop detected for property 'isIconShaped'",
                // confirmed firing repeatedly in the live log).
                property bool isIconShaped: false
                // Also hides itself once the backing notification is gone
                // (post-discard) and on a failed decode - a bad/garbled
                // decode used to render as raw visual noise instead of just
                // not showing anything.
                visible: root.hasImage && root.notifStillAlive && imageContent.status !== Image.Error
                Layout.fillWidth: !imageBox.isIconShaped
                Layout.alignment: Qt.AlignLeft
                implicitWidth: imageBox.isIconShaped ? 48 : 300
                implicitHeight: imageBox.isIconShaped ? 48
                    : (imageContent.status === Image.Ready ? Math.min(imageContent.implicitHeight, 72) : 60)
                radius: imageBox.isIconShaped ? implicitWidth * 0.28 : Looks.radius.medium
                antialiasing: imageBox.isIconShaped
                color: ColorUtils.applyAlpha(SMColors.fg, 0.08)
                clip: true

                Image {
                    id: imageContent
                    anchors.fill: parent
                    // Cleared once the notification is gone instead of
                    // staying bound to root.notifImage - stops this Image
                    // re-requesting the image://qsimage/<id>/1 provider
                    // handle after Notifications.qml has already freed it.
                    source: root.notifStillAlive ? root.notifImage : ""
                    // Fixed, generous decode cap - not tied to the final
                    // display size (which now depends on the image's own
                    // aspect ratio) - a raster source larger than this
                    // downscales, smaller never gets artificially upscaled.
                    sourceSize.width: 300
                    sourceSize.height: 300
                    fillMode: imageBox.isIconShaped ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            const aspect = implicitHeight > 0 ? implicitWidth / implicitHeight : 1
                            imageBox.isIconShaped = aspect > 0.75 && aspect < 1.34
                        }
                    }

                    // Loading placeholder
                    Rectangle {
                        anchors.fill: parent
                        visible: imageContent.status === Image.Loading
                        color: ColorUtils.applyAlpha(SMColors.fg, 0.08)

                        WText {
                            anchors.centerIn: parent
                            text: Translation.tr("Loading...")
                            font.pixelSize: Looks.font.pixelSize.small
                            color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                        }
                    }
                }
            }

            // Body
            WText {
                Layout.fillWidth: true
                text: NotificationUtils.processNotificationBody(root.notifBody, root.notifAppName || root.notifSummary).replace(/\n/g, "<br/>")
                font.pixelSize: Looks.font.pixelSize.normal
                color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                wrapMode: Text.Wrap
                textFormat: Text.RichText
                maximumLineCount: 5
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Actions row - improved layout
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Dismiss button
                NotifPillButton {
                    id: dismissBtn
                    implicitWidth: 40
                    onClicked: root.dismiss()

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "dismiss"
                        implicitSize: 14
                        color: SMColors.fg
                    }

                    WToolTip {
                        text: Translation.tr("Dismiss")
                        visible: dismissBtn.hovered
                    }
                }

                // Custom actions from notification
                Repeater {
                    model: root.notifActions

                    delegate: NotifPillButton {
                        id: actionBtn
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        // First action is primary - gets the wallust-synced
                        // accent tint instead of a flat near-opaque fill.
                        primary: index === 0

                        onClicked: Notifications.attemptInvokeAction(root.notifId, modelData.identifier)

                        WText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, actionBtn.width - 12)
                            // Falls back to the raw identifier so a button
                            // never renders fully blank, regardless of what
                            // a given app puts in its action payload.
                            text: actionBtn.modelData.text || actionBtn.modelData.identifier
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: actionBtn.index === 0 ? Looks.font.weight.strong : Looks.font.weight.regular
                            color: SMColors.fg
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Copy button
                NotifPillButton {
                    id: copyBtn
                    implicitWidth: 40
                    property bool copied: false

                    onClicked: {
                        copyProcess.running = true
                    }

                    Process {
                        id: copyProcess
                        command: ["wl-copy", root.notifBody]
                        onExited: (code, status) => {
                            if (code === 0) {
                                copyBtn.copied = true
                                copyTimer.restart()
                            }
                        }
                    }

                    Timer {
                        id: copyTimer
                        interval: 1500
                        onTriggered: copyBtn.copied = false
                    }

                    WToolTip {
                        text: copyBtn.copied ? Translation.tr("Copied!") : Translation.tr("Copy")
                        visible: copyBtn.hovered
                    }

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: copyBtn.copied ? "checkmark" : "copy"
                        implicitSize: 14
                        color: copyBtn.copied ? WallustColors.cyan : SMColors.fg
                    }
                }
            }
        }
    }
}
