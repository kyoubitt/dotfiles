pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu

/**
 * Windows 11 style notification group with swipe-to-dismiss
 */
Item {
    id: root
    
    required property var notificationGroup
    property int index: 0
    property var qmlParent: root?.parent?.parent
    // This card's containing window's own absolute screen origin - see
    // WaffleNotificationPopup.qml for where this is computed. Composed
    // with background.mapToItem(null, ...) below for backdrop blur
    // alignment that stays correct as cards stack/reorder/animate.
    property real windowScreenX: 0
    property real windowScreenY: 0
    
    readonly property var notifications: notificationGroup?.notifications ?? []
    readonly property int notificationCount: notifications.length
    readonly property bool multipleNotifications: notificationCount > 1
    readonly property bool hasCritical: notifications.some(n => n.urgency === NotificationUrgency.Critical)
    property bool expanded: false
    
    implicitHeight: background.height
    
    // Smooth height changes - disabled for performance
    Behavior on implicitHeight {
        enabled: false
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    function dismissAll() {
        for (let i = 0; i < notifications.length; i++) {
            Notifications.discardNotification(notifications[i].notificationId)
        }
    }

    // A soft, growing hover-circle icon button - the same recipe as
    // DockFlatIcon in the side dock's WSideDockContent.qml, so notification
    // chrome reads as the same material as the rest of the shell instead of
    // a flat default-Qt control.
    // No custom default property here (unlike GhostPill/DockFlatIcon) -
    // callers mix a visual FluentIcon with a non-visual WToolTip as
    // children, and a `list<Item>`-typed content alias (Item.children)
    // rejects the WToolTip outright ("Cannot assign ... expected
    // QQuickItem"). Item's own default `data` property already accepts
    // both, so children just anchor themselves to `parent` directly.
    component NotifIconButton: Item {
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

    // Swipe to dismiss (when collapsed)
    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.dismissAll()
            } else if (mouse.button === Qt.LeftButton && !dragging) {
                root.expanded = !root.expanded
            }
        }

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > 80) {
                root.dismissAll()
            } else {
                dragManager.resetDrag()
            }
        }
    }

    // Cancel timeout on hover
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        
        onContainsMouseChanged: {
            if (containsMouse) {
                const notifs = root.notifications
                for (let i = 0; i < notifs.length; i++) {
                    Notifications.cancelTimeout(notifs[i].notificationId)
                }
            }
        }
    }

    // Swipe progress indicator - hidden for cleaner look
    Rectangle {
        visible: false
        anchors.right: dragManager.dragDiffX < 0 ? parent.right : undefined
        anchors.left: dragManager.dragDiffX > 0 ? parent.left : undefined
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 20
        color: WallustColors.red
        opacity: Math.min(Math.abs(dragManager.dragDiffX) / 80, 1) * 0.8

        FluentIcon {
            anchors.centerIn: parent
            icon: "dismiss"
            implicitSize: 16
            color: SMColors.fg
        }
    }

    // Shadow behind the card - a bit stronger than the default so the card
    // reads as floating above the wallpaper instead of flat against it.
    WRectangularShadow {
        visible: Appearance.effectsEnabled
        target: background
        blur: 12
        spread: 0
    }

    Rectangle {
        id: background
        width: parent.width
        height: content.height + 16
        x: root.expanded ? 0 : dragManager.dragDiffX
        // Genuine background blur sits behind this card (see below) - the
        // frosted tint overlay keeps the GhostPill color recipe on top of
        // it rather than replacing it, instead of a flat fill directly here.
        color: "transparent"
        // Full pill when collapsed (single or grouped); capped once
        // expanded so a tall card keeps soft corners instead of turning
        // into a giant oval.
        radius: root.expanded ? Math.min(height / 2, 28) : height / 2
        antialiasing: true
        border.color: root.hasCritical ? WallustColors.red : ColorUtils.applyAlpha(SMColors.fg, 0.45)
        border.width: root.hasCritical ? 1.5 : 1.2
        
        Behavior on x {
            enabled: false
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: false
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on color {
            enabled: false
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Rectangle's `clip` only crops to the bounding box, not the rounded
        // shape, so the glass layers sit in one item masked by the card's
        // own radius - otherwise the fill paints square corners over the
        // pill-shaped border.
        Item {
            id: glass
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: glass.width
                    height: glass.height
                    radius: background.radius
                    antialiasing: true
                }
            }

            BlurredBackdrop {
                anchors.fill: parent
                screenX: root.windowScreenX + background.mapToItem(null, 0, 0).x
                screenY: root.windowScreenY + background.mapToItem(null, 0, 0).y
            }

            // Frosted capsule tint - same recipe as the dock's GhostPill
            // (WSideDockContent.qml) instead of a flat near-opaque material
            // fill, so the card reads as the same glass as the rest of the
            // shell. Critical notifications mix in a touch of the wallust-
            // synced danger color instead of the old Looks.colors.danger.
            Rectangle {
                anchors.fill: parent
                color: root.hasCritical
                    ? ColorUtils.mix(ColorUtils.applyAlpha(SMColors.fg, 0.10), WallustColors.red, 0.3)
                    : ColorUtils.applyAlpha(SMColors.fg, 0.10)
            }

            // A faint top highlight so the card still reads as glass catching
            // light even when the blurred backdrop lands on a plain/flat part
            // of the wallpaper with nothing visually distinct to blur.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.35
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(SMColors.fg, 0.1) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            // Extra side room so content clears the pill's round ends
            anchors.topMargin: 8
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 6

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                WNotificationAppIcon {
                    icon: root.notificationGroup?.appIcon ?? ""
                    implicitSize: 18
                }

                // Title over a one-line body, same stacked layout as the
                // toast (ToastNotification.qml) instead of a separate row.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    WText {
                        Layout.fillWidth: true
                        text: root.multipleNotifications
                            ? (root.notificationGroup?.appName ?? "")
                            : (root.notifications[0]?.summary ?? "")
                        font.pixelSize: root.multipleNotifications
                            ? Looks.font.pixelSize.small
                            : Looks.font.pixelSize.normal
                        font.weight: root.multipleNotifications
                            ? Looks.font.weight.regular
                            : Looks.font.weight.strong
                        color: root.multipleNotifications ? ColorUtils.applyAlpha(SMColors.fg, 0.7) : SMColors.fg
                        elide: Text.ElideRight
                    }

                    // Collapsed: first notification body
                    WText {
                        visible: !root.expanded && !root.multipleNotifications
                        Layout.fillWidth: true
                        text: {
                            const body = root.notifications[0]?.body ?? ""
                            const appName = root.notifications[0]?.appName ?? root.notifications[0]?.summary ?? ""
                            return NotificationUtils.processNotificationBody(body, appName).replace(/\n/g, " ")
                        }
                        font.pixelSize: Looks.font.pixelSize.small
                        color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                WText {
                    visible: root.expanded
                    text: NotificationUtils.getFriendlyNotifTimeString(root.notificationGroup?.time)
                    font.pixelSize: Looks.font.pixelSize.small
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                }

                // Count badge
                Rectangle {
                    visible: root.multipleNotifications
                    implicitWidth: Math.max(countText.implicitWidth + 10, 20)
                    implicitHeight: 18
                    radius: 9
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.14)

                    WText {
                        id: countText
                        anchors.centerIn: parent
                        text: root.notificationCount.toString()
                        font.pixelSize: Looks.font.pixelSize.small
                        color: SMColors.fg
                    }
                }

                // Expand/collapse indicator - purely decorative, the whole
                // card already toggles expand on click via DragManager above.
                Rectangle {
                    visible: root.expanded && (root.multipleNotifications || root.notifications[0]?.actions?.length > 0)
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Looks.radius.medium
                    color: "transparent"

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "chevron-down"
                        implicitSize: 12
                        color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                        rotation: root.expanded ? 180 : 0

                        Behavior on rotation {
                            animation: Looks.transition.rotate.createObject(this)
                        }
                    }
                }

                // Close all button
                NotifIconButton {
                    id: closeBtn
                    baseSize: 20
                    hoverSize: 26
                    onClicked: root.dismissAll()

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "dismiss"
                        implicitSize: 12
                        color: closeBtn.hovered ? SMColors.fg : ColorUtils.applyAlpha(SMColors.fg, 0.7)
                    }

                    WToolTip {
                        text: root.multipleNotifications ? Translation.tr("Dismiss all") : Translation.tr("Dismiss")
                        visible: closeBtn.hovered
                    }
                }
            }

            // Collapsed multi: show summaries
            Column {
                id: summaryColumn
                visible: !root.expanded && root.multipleNotifications
                opacity: visible ? 1 : 0
                Layout.fillWidth: true
                spacing: 2

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: Math.min(root.notificationCount, 3)

                    WText {
                        required property int index
                        // Bound to the Column's own id, not `parent.width` -
                        // a Repeater delegate's parent at creation time is
                        // the Repeater itself, not the Column it visually
                        // ends up inside, so `parent.width` threw
                        // "Cannot read property 'width' of null" on every
                        // multi-notification group.
                        width: summaryColumn.width
                        text: root.notifications[index]?.summary ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: ColorUtils.applyAlpha(SMColors.fg, 0.7)
                        elide: Text.ElideRight
                        opacity: index === 2 ? 0.5 : 1
                    }
                }
            }

            // Expanded: show full items with staggered animation
            Column {
                id: expandedColumn
                visible: root.expanded
                opacity: root.expanded ? 1 : 0
                Layout.fillWidth: true
                spacing: 10

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    model: root.expanded ? root.notifications : []

                    WNotificationItem {
                        id: notifItem
                        required property int index
                        required property var modelData
                        width: parent.width
                        notification: modelData
                        onlyNotification: root.notificationCount === 1
                        
                        // Staggered entrance animation
                        opacity: 0
                        transform: Translate { id: itemTranslate; y: 10 }
                        
                        Component.onCompleted: {
                            // Stagger based on index
                            entranceTimer.interval = 30 * index
                            entranceTimer.start()
                        }
                        
                        Timer {
                            id: entranceTimer
                            onTriggered: entranceAnim.start()
                        }
                        
                        ParallelAnimation {
                            id: entranceAnim
                            NumberAnimation {
                                target: notifItem
                                property: "opacity"
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: itemTranslate
                                property: "y"
                                to: 0
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
