// Toggle tiles after end-4/dots-hyprland's AndroidQuickToggleButton (GPL-3.0): a pill when off, a rounded rectangle when on.
import QtQuick
import Quickshell.Bluetooth
import qs
import qs.services

// The toggle grid: two tiles to a row, the last one alone takes the whole row. Click flips a setting; right-click opens
// that setting's details.
Flow {
    id: root

    spacing: 8

    function details(kind: string): void { BarState.sidebar = ""; GlobalStates.barPopup = { kind: kind, x: 1700 } }

    component Tile: BarButton {
        id: tile
        property string icon
        property string title
        property string sub
        property bool on: false
        // Right-click opens details. As in end-4's wide toggles, only the icon chip lights up then; a plain toggle
        // fills the whole tile with the accent.
        property bool menu: false
        // The last tile of an odd count takes the whole row.
        property bool wide: false
        readonly property bool whole: on && !menu
        readonly property int chipSize: height - 12

        tone: whole ? "filled" : "tonal"
        width: wide ? root.width : Math.floor((root.width - 8) / 2)
        height: 54
        // the shape is the state: round when off, squarer when on, tight while pressed
        radius: pressed ? BarStyle.radiusMedium : (on ? BarStyle.radiusLarge : height / 2)
        Behavior on radius { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }

        Rectangle {
            id: chip
            x: 6; anchors.verticalCenter: parent.verticalCenter
            width: tile.chipSize; height: tile.chipSize
            radius: Math.max(0, tile.radius - 6)
            color: tile.menu ? (tile.on ? BarStyle.accent : BarStyle.cardHigh) : "transparent"
            Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
            BarIcon { anchors.centerIn: parent; name: tile.icon; fill: tile.on ? 1 : 0; size: 22; color: tile.on ? BarStyle.onAccent : BarStyle.text }
        }
        Column {
            x: chip.x + chip.width + 9
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            BarText { text: tile.title; width: parent.width; elide: Text.ElideRight; font.weight: Font.DemiBold; font.pixelSize: 12; color: tile.ink }
            BarText { text: tile.sub; width: parent.width; elide: Text.ElideRight; font.pixelSize: 11; color: tile.inkSoft; opacity: tile.whole ? 0.85 : 1 }
        }
    }

    Tile {
        menu: true
        icon: NetLink.iwd ? NetLink.icon : Network.materialSymbol
        title: "Wi-Fi"
        sub: NetLink.iwd ? (NetLink.connected ? NetLink.ssid : (NetLink.wifiEnabled ? "Not connected" : "Off")) : (Network.networkName || "Network")
        on: NetLink.iwd ? NetLink.wifiEnabled : Network.wifiEnabled
        onTapped: NetLink.iwd ? NetLink.setPowered(!NetLink.wifiEnabled) : Network.toggleWifi()
        onSecondary: root.details("network")
    }
    Tile {
        visible: BluetoothStatus.available
        menu: true
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
        menu: true
        icon: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
        title: "Sound"
        sub: (Audio.sink?.audio?.muted ?? false) ? "Muted" : Math.round(Audio.value * 100) + "%"
        on: !(Audio.sink?.audio?.muted ?? false)
        onTapped: Audio.toggleMute()
        onSecondary: root.details("volume")
    }
    Tile { icon: "bedtime"; title: "Night light"; sub: BarTools.nightLight ? "On" : "Off"; on: BarTools.nightLight; onTapped: BarTools.toggleNightLight() }
    Tile { icon: "self_improvement"; title: "Focus"; sub: BarTools.focusMode ? "On" : "Off"; on: BarTools.focusMode; onTapped: BarTools.toggleFocusMode() }
    Tile { wide: BluetoothStatus.available; icon: "coffee"; title: "Caffeine"; sub: BarTools.caffeine ? "Staying awake" : "Off"; on: BarTools.caffeine; onTapped: BarTools.toggleCaffeine() }
}
