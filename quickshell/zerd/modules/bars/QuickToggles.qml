import QtQuick
import Quickshell.Bluetooth
import qs
import qs.services

// The toggle grid. Click flips a setting; right-click opens that setting's details.
Grid {
    id: root

    columns: 2
    spacing: 8

    function details(kind: string): void { BarState.sidebar = ""; GlobalStates.barPopup = { kind: kind, x: 1700 } }

    component Tile: BarButton {
        id: tile
        property string icon
        property string title
        property string sub
        property bool on: false
        toggled: on
        width: (root.width - 8) / 2; height: 62
        radius: tile.pressed ? BarStyle.radiusSmall : BarStyle.radiusMedium
        Behavior on radius { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
        BarIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: tile.icon; fill: tile.on ? 1 : 0; size: 22; color: tile.on ? BarStyle.accent : tile.inkSoft }
        Column {
            x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58
            BarText { text: tile.title; width: parent.width; elide: Text.ElideRight; font.weight: Font.DemiBold; font.pixelSize: 13; color: tile.ink }
            BarText { text: tile.sub; width: parent.width; elide: Text.ElideRight; font.pixelSize: 11; color: tile.inkSoft }
        }
    }

    Tile {
        icon: NetLink.iwd ? NetLink.icon : Network.materialSymbol
        title: "Wi-Fi"
        sub: NetLink.iwd ? (NetLink.connected ? NetLink.ssid : (NetLink.wifiEnabled ? "Not connected" : "Off")) : (Network.networkName || "Network")
        on: NetLink.iwd ? NetLink.wifiEnabled : Network.wifiEnabled
        onTapped: NetLink.iwd ? NetLink.setPowered(!NetLink.wifiEnabled) : Network.toggleWifi()
        onSecondary: root.details("network")
    }
    Tile {
        visible: BluetoothStatus.available
        icon: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
        title: "Bluetooth"
        sub: !BluetoothStatus.enabled ? "Off" : (BluetoothStatus.activeDeviceSummary() || "On")
        on: BluetoothStatus.enabled
        onTapped: { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled }
        onSecondary: root.details("network")
    }
    Tile {
        icon: Notifications.silent ? "notifications_off" : "notifications"
        title: "Do not disturb"
        sub: Notifications.silent ? "On" : "Off"
        on: Notifications.silent
        onTapped: Notifications.toggleSilent()
    }
    Tile {
        icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
        title: "Sound"
        sub: (Audio.sink?.audio?.muted ?? false) ? "Muted" : Math.round(Audio.value * 100) + "%"
        on: !(Audio.sink?.audio?.muted ?? false)
        onTapped: Audio.toggleMute()
        onSecondary: root.details("volume")
    }
    Tile { icon: "bedtime"; title: "Night light"; sub: BarTools.nightLight ? "On" : "Off"; on: BarTools.nightLight; onTapped: BarTools.toggleNightLight() }
    Tile { icon: "self_improvement"; title: "Focus"; sub: BarTools.focusMode ? "On" : "Off"; on: BarTools.focusMode; onTapped: BarTools.toggleFocusMode() }
    Tile { icon: "coffee"; title: "Caffeine"; sub: BarTools.caffeine ? "Staying awake" : "Off"; on: BarTools.caffeine; onTapped: BarTools.toggleCaffeine() }
}
