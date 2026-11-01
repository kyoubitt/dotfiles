pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Notification banners: up to three stacked cards under the bar, newest on top. Each has the app's icon,
// title, text and actions; hover holds it on screen, click opens the app, x dismisses. Per-app rules
// (NotifRules) can keep an app's banners off the screen or drop them altogether.
Scope {
    id: root

    readonly property var options: Config.options?.bars?.notifications ?? ({})
    readonly property real cardWidth: options.width ?? 380
    readonly property bool topRight: (options.position ?? "top") === "topRight"
    // An icon name for an app that did not send one: its desktop entry, or the best guess.
    function iconFor(app: string): string { return AppSearch.lookupDesktopEntry(app)?.icon || AppSearch.guessIcon(app) }
    readonly property var raw: Notifications.popupList ?? []
    readonly property var shown: raw.filter(n => NotifRules.modeOf(n.appName) === "normal").slice(-3).reverse()

    // Rules act as banners arrive. Done a moment later, outside the change that announced them:
    // dismissing a banner edits the list that triggered the check.
    onRawChanged: sweep.restart()
    Timer {
        id: sweep
        interval: 20
        onTriggered: {
            for (const n of root.raw.slice()) {
                const mode = NotifRules.modeOf(n.appName)
                if (mode === "silent") Notifications.timeoutNotification(n.notificationId)
                else if (mode === "mute") Notifications.discardNotification(n.notificationId)
            }
        }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === GlobalStates.focusedScreen?.name) ?? Quickshell.screens[0]
        visible: root.shown.length > 0 && !Notifications.silent
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:zerd-notifications"
        anchors { top: true; left: !root.topRight; right: true }
        margins.top: BarState.barShown ? 58 : 14
        Behavior on margins.top { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        margins.right: root.topRight ? 12 : 0
        implicitWidth: root.topRight ? root.cardWidth + 24 : (screen?.width ?? 1920)
        implicitHeight: Math.max(1, column.height + 24)
        mask: Region { item: column }

        ListView {
            id: column
            anchors.top: parent.top
            anchors.topMargin: 6
            x: root.topRight ? 12 : Math.round((parent.width - width) / 2)
            width: root.cardWidth
            height: Math.max(1, contentHeight)
            spacing: 8
            interactive: false
            // The stack glides: a new banner slides in from above while the others make room, a leaving one
            // fades out and the rest close up; nothing jumps.
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                    NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 170; easing.type: Easing.OutCubic }
                }
            }
            displaced: Transition { NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic } }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 120 }
                    NumberAnimation { property: "scale"; to: 0.96; duration: 120 }
                }
            }
            model: ScriptModel { objectProp: "notificationId"; values: root.shown }
                delegate: Item {
                    id: card
                    required property var modelData
                    readonly property bool critical: modelData.urgency === "critical"
                    // The default action is what a click does; only real, labelled ones become buttons.
                    readonly property var buttons: (modelData.actions ?? []).filter(a => a.text && a.text.length > 0 && a.identifier !== "default").slice(0, 3)
                    property bool entered: false
                    width: column.width
                    height: body.implicitHeight + 24
                    opacity: entered ? 1 - Math.min(0.85, Math.abs(swipe.translation.x) / width) : 0
                    Component.onCompleted: entered = true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    transform: [
                        Translate { y: card.entered ? 0 : -14; Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } } },
                        Translate { x: swipe.active ? swipe.translation.x : 0 }
                    ]
                    // Drag a banner sideways to dismiss it.
                    DragHandler {
                        id: swipe
                        target: null
                        yAxis.enabled: false
                        onActiveChanged: if (!active && Math.abs(translation.x) > card.width * 0.3) Notifications.discardNotification(card.modelData.notificationId)
                    }
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    // A flat opaque card: no tint, a border only when it is urgent, a soft shadow underneath.
                    Rectangle {
                        anchors.fill: parent; anchors.topMargin: 4; anchors.leftMargin: 3; anchors.rightMargin: 3; anchors.bottomMargin: -4
                        radius: 22; color: "#000000"; opacity: 0.32; z: -2
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 20 }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: BarStyle.surface
                        border.width: card.critical ? 1 : 0
                        border.color: Qt.rgba(BarStyle.danger.r, BarStyle.danger.g, BarStyle.danger.b, 0.7)
                    }
                    Row {
                        id: body
                        x: 14; y: 12
                        spacing: 12
                        width: parent.width - 26
                        // The app's own icon; a sender picture (an avatar, cover art) takes the main spot and
                        // the app icon moves to a small badge on its corner.
                        Item {
                            id: iconBox
                            width: 38; height: 38
                            readonly property string appIcon: card.modelData.appIcon.length > 0 ? card.modelData.appIcon : root.iconFor(card.modelData.appName)
                            readonly property bool hasImage: card.modelData.image.length > 0
                            // a picture that came with the notification (an avatar, cover art) in a rounded square
                            ClippingRectangle {
                                visible: iconBox.hasImage
                                anchors.fill: parent; radius: 12; color: BarStyle.plateHover
                                IconImage { anchors.fill: parent; source: iconBox.hasImage ? card.modelData.image : ""; mipmap: true }
                            }
                            // otherwise the app's own icon, as it is
                            SmartAppIcon { visible: !iconBox.hasImage; anchors.centerIn: parent; icon: iconBox.appIcon; iconSize: 38 }
                            // with a picture, the app icon is a small badge on its corner
                            SmartAppIcon { visible: iconBox.hasImage; x: 22; y: 22; icon: iconBox.appIcon; iconSize: 18 }
                        }
                        Column {
                            width: parent.width - 38 - 12
                            spacing: 1
                            Item {
                                width: parent.width; height: summaryText.implicitHeight
                                BarText { id: summaryText; width: parent.width - timeText.implicitWidth - 8; text: card.modelData.summary.length > 0 ? card.modelData.summary : card.modelData.appName; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                BarText { id: timeText; anchors.right: parent.right; text: "now"; font.pixelSize: 12; color: BarStyle.subtext }
                            }
                            Text {
                                visible: card.modelData.body.length > 0
                                width: parent.width
                                text: card.modelData.body
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: hover.hovered ? 8 : 2
                                elide: Text.ElideRight
                                color: BarStyle.subtext
                                font.pixelSize: 13
                                font.family: Appearance.font.family.expressive
                                renderType: Text.NativeRendering
                            }
                            BarText { visible: card.modelData.summary.length > 0 && card.modelData.summary !== card.modelData.appName; text: card.modelData.appName; font.pixelSize: 11; color: BarStyle.subtext; width: Math.min(implicitWidth, parent.width); elide: Text.ElideRight }
                            Flow {
                                visible: card.buttons.length > 0 || hover.hovered
                                topPadding: 8
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: card.buttons
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: actionText.implicitWidth + 24; height: 28; radius: 14
                                        color: actionHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
                                        Behavior on color { ColorAnimation { duration: 90 } }
                                        BarText { id: actionText; anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: 12; font.weight: Font.Medium }
                                        HoverHandler { id: actionHover }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.attemptInvokeAction(card.modelData.notificationId, parent.modelData.identifier) }
                                    }
                                }
                                // quiet this app from here
                                Rectangle {
                                    visible: hover.hovered
                                    width: muteText.implicitWidth + 24; height: 28; radius: 14
                                    color: "transparent"; border.width: 1; border.color: BarStyle.border
                                    BarText { id: muteText; anchors.centerIn: parent; text: "Mute " + card.modelData.appName; font.pixelSize: 11; color: BarStyle.subtext; width: Math.min(implicitWidth, 120); elide: Text.ElideRight }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifRules.setMode(card.modelData.appName, "silent") }
                                }
                            }
                        }
                    }
                    // dismiss: a small circle on the top-left corner, only while the pointer is on the card
                    Rectangle {
                        x: 5; y: 5; width: 22; height: 22; radius: 11
                        opacity: hover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        color: closeHover.hovered ? BarStyle.plateHover : BarStyle.surface
                        border.width: 1; border.color: BarStyle.border
                        BarIcon { anchors.centerIn: parent; name: "close"; size: 13 }
                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: hover.hovered; onTapped: Notifications.discardNotification(card.modelData.notificationId) }
                    }
                    HoverHandler {
                        id: hover
                        onHoveredChanged: {
                            if (hovered) Notifications.cancelTimeout(card.modelData.notificationId)
                            else card.modelData.timer?.restart()
                        }
                    }
                    TapHandler {
                        onTapped: {
                            const actions = card.modelData.actions ?? []
                            const preferred = actions.find(a => a.identifier === "default")
                            if (preferred) Notifications.attemptInvokeAction(card.modelData.notificationId, preferred.identifier)
                            else Notifications.timeoutNotification(card.modelData.notificationId)
                        }
                    }
                }
        }
    }
}
