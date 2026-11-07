import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common.widgets

// Volume after ilyamiro's volume popup (serpantinum, AGPL-3.0): the active device on top with its level and mute, then
// tabs for outputs, inputs and the apps that make sound, each a list you can pick from or turn up and down.
Column {
    id: root

    property int tab: 0
    readonly property bool outputs: tab !== 1
    readonly property var node: root.outputs ? Audio.sink : Audio.source
    readonly property bool muted: root.node?.audio?.muted ?? false
    readonly property real level: root.node?.audio?.volume ?? 0
    readonly property var devices: root.tab === 1 ? Audio.inputDevices : Audio.outputDevices
    spacing: 12
    width: 320

    // Streams and devices must be bound before their volume can be read or set.
    PwObjectTracker { objects: Audio.outputAppNodes.concat(Audio.inputDevices, Audio.outputDevices) }

    function setLevel(n: var, v: real): void {
        if (!n?.audio) return
        if (n === Audio.sink) { n.audio.muted = false; Audio.setSinkVolume(v) }
        else { n.audio.muted = false; n.audio.volume = v }
    }
    function iconFor(app: var): string { return AppSearch.lookupDesktopEntry(app.properties?.["application.icon-name"] ?? "")?.icon || AppSearch.guessIcon(app.properties?.["application.icon-name"] || app.properties?.["application.name"] || "") }

    // the active device
    Row {
        spacing: 12
        Rectangle {
            width: 44; height: 44; radius: 22
            color: root.muted ? BarStyle.cardHigh : BarStyle.accentContainer
            BarIcon {
                anchors.centerIn: parent; size: 22; fill: 1
                name: root.outputs ? (root.muted || root.level <= 0 ? "volume_off" : root.level < 0.5 ? "volume_down" : "volume_up") : (root.muted ? "mic_off" : "mic")
                color: root.muted ? BarStyle.subtext : BarStyle.onAccentContainer
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 320 - 44 - 12 - 44 - 12
            BarText { width: parent.width; text: Audio.friendlyDeviceName(root.node); font.weight: Font.DemiBold; elide: Text.ElideRight }
            BarText { text: root.muted ? "Muted" : Math.round(root.level * 100) + "%"; font.pixelSize: 12; color: BarStyle.subtext }
        }
        BarButton {
            id: muteBtn
            width: 44; height: 44; radius: pressed ? BarStyle.radiusSmall : 22
            tone: "tonal"; toggled: root.muted
            onTapped: root.outputs ? Audio.toggleMute() : Audio.toggleMicMute()
            BarIcon { anchors.centerIn: parent; name: root.muted ? "volume_off" : "volume_up"; color: muteBtn.ink }
        }
    }
    BarSlider {
        width: parent.width
        icon: root.outputs ? "volume_up" : "mic"
        value: root.muted ? 0 : root.level
        onMoved: v => root.setLevel(root.node, v)
    }

    BarTabs {
        width: parent.width
        model: [{ icon: "speaker", text: "Output" }, { icon: "mic", text: "Input" }, { icon: "apps", text: "Apps" }]
        current: root.tab
        onPicked: i => root.tab = i
    }

    // outputs and inputs: pick the one to use
    Column {
        visible: root.tab !== 2
        width: parent.width
        spacing: 2
        BarText { visible: root.devices.length === 0; text: "Nothing found"; color: BarStyle.subtext; font.pixelSize: 12 }
        Repeater {
            model: root.devices
            delegate: Item {
                id: dev
                required property var modelData
                readonly property bool current: modelData === root.node
                width: parent.width; height: 40
                BarHoverFill { anchors.fill: parent; hovered: devMa.containsMouse; pressed: devMa.pressed }
                BarIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: dev.current ? "radio_button_checked" : "radio_button_unchecked"; size: 20; color: dev.current ? BarStyle.accent : BarStyle.subtext }
                BarText { x: 42; width: parent.width - 54; anchors.verticalCenter: parent.verticalCenter; text: Audio.friendlyDeviceName(dev.modelData); elide: Text.ElideRight; font.weight: dev.current ? Font.DemiBold : Font.Medium }
                MouseArea {
                    id: devMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab === 1 ? Audio.setDefaultSource(dev.modelData) : Audio.setDefaultSink(dev.modelData)
                }
            }
        }
    }

    // apps: one slider each
    Flickable {
        visible: root.tab === 2
        width: parent.width
        height: Math.min(appCol.height, 252)
        contentHeight: appCol.height
        clip: true
        interactive: appCol.height > height
        Column {
            id: appCol
            width: parent.width
            spacing: 2
            BarText { visible: Audio.outputAppNodes.length === 0; text: "Nothing is playing"; color: BarStyle.subtext; font.pixelSize: 12 }
            Repeater {
                model: Audio.outputAppNodes
                delegate: Item {
                    id: app
                    required property var modelData
                    readonly property real vol: modelData.audio?.volume ?? 0
                    readonly property bool mute: modelData.audio?.muted ?? false
                    width: appCol.width; height: 48
                    SmartAppIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; iconSize: 28; icon: root.iconFor(app.modelData) }
                    Column {
                        x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48 - 40
                        spacing: 2
                        BarText { width: parent.width; text: Audio.appNodeDisplayName(app.modelData); font.pixelSize: 12; elide: Text.ElideRight }
                        BarSlider {
                            width: parent.width; trackHeight: 20
                            value: app.mute ? 0 : app.vol
                            label: Math.round(app.vol * 100) + "%"
                            onMoved: v => root.setLevel(app.modelData, v)
                        }
                    }
                    BarButton {
                        id: appMute
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        width: 32; height: 32; radius: 16
                        tone: "plain"; toggled: app.mute
                        onTapped: { if (app.modelData.audio) app.modelData.audio.muted = !app.mute }
                        BarIcon { anchors.centerIn: parent; size: 18; name: app.mute ? "volume_off" : "volume_up"; color: appMute.ink }
                    }
                }
            }
        }
    }
}
