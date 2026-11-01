import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.bars
import qs.modules.music

// You: your Spotify picture and name, what Spotify lets an app show, the way to edit it (Spotify only allows that on
// its own site), your devices, and sign out.
Flickable {
    id: root
    property var devices: []
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: MusicApi.devices(d => root.devices = d)

    Column {
        id: col
        x: 34; y: 26; width: root.width - 68; spacing: 18
        Row {
            spacing: 26
            ClippingRectangle {
                width: 170; height: 170; radius: 85; color: MusicStore.accent
                Image { anchors.fill: parent; source: (MusicStore.me?.images ?? [])[0]?.url ?? ""; sourceSize: Qt.size(340, 340); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; visible: status === Image.Ready }
                EText { anchors.centerIn: parent; visible: !(MusicStore.me?.images ?? []).length; text: (MusicStore.name || "?").charAt(0).toUpperCase(); font.pixelSize: 64; font.weight: Font.Bold; color: MusicStore.onAccent }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                EText { text: "Profile"; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.subtext }
                EText { text: MusicStore.name; font.pixelSize: 40; font.weight: Font.Bold }
                EText { color: BarStyle.subtext
                    text: MusicStore.lists.length + " playlists" + ((MusicStore.me?.followers?.total ?? -1) >= 0 ? "  ·  " + MusicStore.me.followers.total + " followers" : "") }
                Row {
                    spacing: 10; topPadding: 8
                    Pill { text: "Edit profile"; icon: "edit"; onTapped: Quickshell.execDetached(["xdg-open", "https://www.spotify.com/account/profile/"]) }
                    Pill { text: "Account"; icon: "manage_accounts"; filled: false; onTapped: Quickshell.execDetached(["xdg-open", "https://www.spotify.com/account/overview/"]) }
                    Pill { text: "Sign out"; icon: "logout"; filled: false; onTapped: MusicApi.signOut() }
                }
            }
        }
        EText { text: "Player"; font.pixelSize: 21; font.weight: Font.DemiBold; topPadding: 10 }
        Row {
            spacing: 12
            Repeater {
                model: [{ v: "app", t: "Spotify app", s: "Orbit controls the Spotify desktop app you already run", i: "desktop_windows" },
                        { v: "soloist", t: "Orbit player", s: !SoloistPlayer.installed ? "Needs Spotify's Soloist (see the README)" : (SoloistPlayer.loggedIn ? "Plays on its own: the Spotify app can stay closed" : "Pick \"Orbit\" once in the Spotify app's device list"), i: "bolt" }]
                delegate: Rectangle {
                    id: en
                    required property var modelData
                    readonly property bool on: EchoPlayer.engine === modelData.v
                    width: Math.floor((col.width - 12) / 2); height: 92; radius: 26
                    color: on ? Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.22) : (enHov.hovered ? BarStyle.plateHover : BarStyle.plate)
                    border.width: 1; border.color: on ? MusicStore.accent : BarStyle.border
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Cookie { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 48; height: 48; color: en.on ? MusicStore.accent : Qt.rgba(1, 1, 1, 0.1); lobes: 8; amp: 0.07 }
                    BarIcon { x: 31; anchors.verticalCenter: parent.verticalCenter; name: en.modelData.i; size: 22; color: en.on ? MusicStore.onAccent : BarStyle.text }
                    Column { x: 84; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; spacing: 3
                        EText { text: en.modelData.t; font.weight: Font.DemiBold }
                        EText { width: parent.width; wrapMode: Text.Wrap; text: en.modelData.s; font.pixelSize: 12; color: BarStyle.subtext } }
                    HoverHandler { id: enHov }
                    TapHandler { onTapped: { Config.setNestedValue("music.engine", en.modelData.v); if (en.modelData.v === "soloist") SoloistPlayer.start(); else SoloistPlayer.stop(); EchoPlayer.stop() } }
                }
            }
        }
        EText { visible: EchoPlayer.engine === "soloist" && SoloistPlayer.note.length > 0; text: SoloistPlayer.note; color: BarStyle.danger; font.pixelSize: 12 }
        EText { visible: EchoPlayer.note.length > 0; text: EchoPlayer.note; color: BarStyle.danger; font.pixelSize: 12 }
        EText { text: "Play on"; font.pixelSize: 21; font.weight: Font.DemiBold; topPadding: 10 }
        EText { visible: root.devices.length === 0; text: "No Spotify device is awake. Open Spotify on a device, or start the Orbit player."; color: BarStyle.subtext }
        Flow {
            width: parent.width; spacing: 10
            Repeater {
                model: root.devices
                delegate: Rectangle {
                    id: dv
                    required property var modelData
                    width: 260; height: 76; radius: 24
                    color: modelData.is_active ? Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.22) : (dvHov.hovered ? BarStyle.plateHover : BarStyle.plate)
                    border.width: 1; border.color: modelData.is_active ? MusicStore.accent : BarStyle.border
                    Behavior on color { ColorAnimation { duration: 90 } }
                    BarIcon { x: 20; anchors.verticalCenter: parent.verticalCenter; size: 28; color: dv.modelData.is_active ? MusicStore.accent : BarStyle.subtext
                        name: dv.modelData.type === "Smartphone" ? "smartphone" : (dv.modelData.type === "Speaker" ? "speaker" : "computer") }
                    Column { x: 64; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80
                        EText { width: parent.width; elide: Text.ElideRight; text: dv.modelData.name; font.weight: Font.DemiBold }
                        EText { text: dv.modelData.is_active ? "Playing here" : dv.modelData.type; font.pixelSize: 12; color: BarStyle.subtext } }
                    HoverHandler { id: dvHov }
                    TapHandler { onTapped: { MusicApi.transfer(dv.modelData.id); MusicStore.tell("Playing on " + dv.modelData.name); MusicApi.devices(d => root.devices = d) } }
                }
            }
        }
        EText { text: "Trash bin"; font.pixelSize: 21; font.weight: Font.DemiBold; topPadding: 10 }
        EText { text: MusicStore.trash.length === 0 ? "Songs you throw away are skipped and listed here." : MusicStore.trash.length + " songs are skipped." ; color: BarStyle.subtext }
        Pill { visible: MusicStore.trash.length > 0; text: "Bring them all back"; filled: false; onTapped: { MusicStore.clearTrash() } }
    }
}
