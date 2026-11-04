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
    readonly property var visibleRaw: raw.filter(n => NotifRules.modeOf(n.appName) === "normal")
    // repeats from one app share a banner: the newest one shows, with a count ("Messages · 3 new")
    readonly property var counts: {
        const m = {}
        for (const n of root.visibleRaw) m[n.appName] = (m[n.appName] ?? 0) + 1
        return m
    }
    readonly property var shown: {
        const seen = {}, out = []
        for (const n of root.visibleRaw.slice().reverse()) {
            if (seen[n.appName]) continue
            seen[n.appName] = true
            out.push(n)
            if (out.length === 3) break
        }
        return out
    }

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
                    readonly property bool critical: String(modelData.urgency).toLowerCase() === "critical"
                    // The default action is what a click does; only real, labelled ones become buttons.
                    readonly property var buttons: (modelData.actions ?? []).filter(a => a.text && a.text.length > 0 && a.identifier !== "default").slice(0, 3)
                    property bool entered: false
                    // "now", "3 min ago" ... kept fresh while the banner is up
                    property int tick: 0
                    readonly property string age: {
                        void card.tick
                        const t = card.modelData.time ?? 0
                        const ms = Date.now() - (t > 1e12 ? t : t * 1000)
                        const m = Math.floor(ms / 60000)
                        return m < 1 ? "now" : m < 60 ? m + " min ago" : Math.floor(m / 60) + " h ago"
                    }
                    Timer { interval: 20000; repeat: true; running: true; onTriggered: card.tick++ }
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
                        radius: BarStyle.radiusLarge; color: "#000000"; opacity: BarStyle.shadowOpacity; z: -2
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 20 }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: BarStyle.radiusLarge
                        color: BarStyle.surface
                        border.width: 1
                        border.color: card.critical ? Qt.rgba(BarStyle.danger.r, BarStyle.danger.g, BarStyle.danger.b, 0.7) : BarStyle.edge
                    }
                    // urgent: a soft red glow along the left edge that breathes
                    Rectangle {
                        visible: card.critical
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * 0.4; radius: BarStyle.radiusLarge
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(BarStyle.danger.r, BarStyle.danger.g, BarStyle.danger.b, 0.22) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        SequentialAnimation on opacity { running: card.critical; loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1600; easing.type: Easing.InOutSine } }
                    }
                    Row {
                        id: body
                        x: 14; y: 12
                        spacing: 12
                        width: parent.width - 26
                        // The app's own icon; a sender picture (an avatar, cover art) takes the main spot and
                        // the app icon moves to a small badge on its corner.
                        NotifIcon {
                            id: iconBox
                            size: 42
                            appName: card.modelData.appName
                            appIcon: card.modelData.appIcon
                            summary: card.modelData.summary
                            image: card.modelData.image
                            critical: card.critical
                        }
                        Column {
                            width: parent.width - 42 - 12
                            spacing: 2
                            // who sent it, and how long ago
                            BarText {
                                width: parent.width; elide: Text.ElideRight
                                text: card.modelData.appName + ((root.counts[card.modelData.appName] ?? 1) > 1 ? " · " + root.counts[card.modelData.appName] + " new" : "") + "  ·  " + card.age
                                font.pixelSize: 11; font.weight: Font.DemiBold; color: BarStyle.subtext
                            }
                            BarText { width: parent.width; elide: Text.ElideRight; text: card.modelData.summary.length > 0 ? card.modelData.summary : card.modelData.appName; font.pixelSize: 14; font.weight: Font.DemiBold }
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
                                renderType: Text.QtRendering
                            }
                            Flow {
                                visible: card.buttons.length > 0 || hover.hovered
                                topPadding: 8
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: card.buttons
                                    delegate: BarButton {
                                        id: actBtn
                                        required property var modelData
                                        tone: "tonal"
                                        width: actionText.implicitWidth + 30; height: 34; radius: BarStyle.radiusSmall
                                        onTapped: Notifications.attemptInvokeAction(card.modelData.notificationId, actBtn.modelData.identifier)
                                        BarText { id: actionText; anchors.centerIn: parent; text: actBtn.modelData.text; font.pixelSize: 12; font.weight: Font.Medium; color: actBtn.ink }
                                    }
                                }
                                // quiet this app from here
                                BarButton {
                                    id: muteBtn
                                    visible: hover.hovered
                                    tone: "outlined"
                                    width: muteText.implicitWidth + 30; height: 34; radius: BarStyle.radiusSmall
                                    onTapped: NotifRules.setMode(card.modelData.appName, "silent")
                                    BarText { id: muteText; anchors.centerIn: parent; text: "Mute " + card.modelData.appName; font.pixelSize: 11; color: muteBtn.inkSoft; width: Math.min(implicitWidth, 120); elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                    // dismiss: a small circle on the top-left corner, only while the pointer is on the card
                    BarButton {
                        id: closeBtn
                        x: 6; y: 6; width: 24; height: 24; radius: 12
                        tone: "tonal"
                        opacity: hover.hovered ? 1 : 0
                        enabled: hover.hovered
                        Behavior on opacity { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
                        onTapped: Notifications.discardNotification(card.modelData.notificationId)
                        BarIcon { anchors.centerIn: parent; name: "close"; size: 14; color: closeBtn.ink }
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
