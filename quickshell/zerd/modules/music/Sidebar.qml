import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.bars

// Left, like Spotify's: a card with where to go, and a card with your library (playlists, albums, artists) that can
// shrink to a rail of covers. Sort it, filter it, hide what you never play. The playlist playing now comes first.
Item {
    id: root
    width: MusicStore.libShown ? 360 : 104
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property var nav: [{ id: "home", t: "Home", i: "home" }, { id: "search", t: "Search", i: "search" }, { id: "liked", t: "Liked Songs", i: "favorite" }, { id: "stats", t: "Stats", i: "monitoring" }]
    property var menuFor: null          // the library entry whose menu is open
    property real menuY: 0

    // ---- navigation card
    Rectangle {
        id: navCard
        x: 8; y: 8; width: parent.width - 8; height: navCol.implicitHeight + 28
        radius: 24; color: Qt.rgba(0, 0, 0, 0.36); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Column {
            id: navCol
            x: 8; y: 14; width: parent.width - 16; spacing: 2
            Row {
                visible: MusicStore.libShown
                x: 12; spacing: 12; bottomPadding: 10
                Image { width: 32; height: 32; source: Qt.resolvedUrl("../../assets/icons/orbit.svg"); sourceSize: Qt.size(64, 64); smooth: true }
                EText { anchors.verticalCenter: parent.verticalCenter; text: "Orbit"; font.pixelSize: 20; font.weight: Font.Bold }
            }
            Repeater {
                model: root.nav
                delegate: Rectangle {
                    id: ni
                    required property var modelData
                    readonly property bool on: MusicStore.page === modelData.id
                    width: navCol.width; height: 46; radius: 23
                    color: on ? Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.2) : (niHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    Behavior on color { ColorAnimation { duration: 90 } }
                    scale: niTap.pressed ? 0.97 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: MusicStore.libShown ? 18 : Math.round((parent.width - 24) / 2)
                        spacing: 16
                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: ni.modelData.i; fill: ni.on ? 1 : 0; size: 24; color: ni.on ? MusicStore.accent : BarStyle.subtext }
                        EText { visible: MusicStore.libShown; anchors.verticalCenter: parent.verticalCenter; text: ni.modelData.t; font.weight: Font.DemiBold; color: ni.on ? MusicStore.accent : BarStyle.text }
                    }
                    HoverHandler { id: niHov }
                    TapHandler { id: niTap; onTapped: MusicStore.go(ni.modelData.id, null) }
                }
            }
        }
    }

    // ---- library card
    Rectangle {
        id: lib
        x: 8; y: navCard.y + navCard.height + 8; width: parent.width - 8; height: parent.height - y - 8
        radius: 24; color: Qt.rgba(0, 0, 0, 0.36); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        clip: true

        // header
        Item {
            id: head
            x: 0; y: 0; width: parent.width; height: 58
            Row {
                visible: MusicStore.libShown
                x: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "library_music"; size: 24; color: BarStyle.subtext }
                EText { anchors.verticalCenter: parent.verticalCenter; text: "Your Library"; font.weight: Font.Bold; font.pixelSize: 16 }
            }
            Row {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } spacing: 2
                visible: MusicStore.libShown
                Rectangle { width: 38; height: 38; radius: 19; color: addH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    BarIcon { anchors.centerIn: parent; name: "add"; size: 24; color: BarStyle.text }
                    HoverHandler { id: addH }
                    TapHandler { onTapped: MusicApi.newPlaylist("New playlist", p => { if (p) { MusicStore.tell("Made \"New playlist\""); MusicStore.load(); MusicStore.go("playlist", p) } }) } }
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.rightMargin: MusicStore.libShown ? 10 : Math.round((parent.width - 38) / 2)
                width: 38; height: 38; radius: 19; color: colH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                visible: true
                BarIcon { anchors.centerIn: parent; name: MusicStore.libShown ? "keyboard_double_arrow_left" : "keyboard_double_arrow_right"; size: 22; color: BarStyle.text }
                HoverHandler { id: colH }
                TapHandler { onTapped: MusicStore.libOpen = !MusicStore.libOpen }
            }
        }
        // chips
        Row {
            id: chips
            visible: MusicStore.libShown
            x: 16; y: head.height; height: 36; spacing: 8
            Repeater {
                model: [{ v: "playlists", l: "Playlists" }, { v: "albums", l: "Albums" }, { v: "artists", l: "Artists" }]
                delegate: Rectangle {
                    id: ch
                    required property var modelData
                    readonly property bool on: MusicStore.libChip === modelData.v
                    width: chT.implicitWidth + 26; height: 34; radius: 17
                    color: on ? MusicStore.accent : (chH.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    Behavior on color { ColorAnimation { duration: 90 } }
                    EText { id: chT; anchors.centerIn: parent; text: ch.modelData.l; font.pixelSize: 13; font.weight: Font.Medium; color: ch.on ? MusicStore.onAccent : BarStyle.text }
                    HoverHandler { id: chH }
                    TapHandler { onTapped: MusicStore.libChip = ch.on ? "all" : ch.modelData.v }
                }
            }
        }
        // find in library, and the sort
        Item {
            id: tools
            visible: MusicStore.libShown
            x: 8; y: head.height + 44; width: parent.width - 16; height: 42
            Rectangle {
                x: 0; width: parent.width - 160; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: lq.activeFocus ? MusicStore.accent : "transparent"
                BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 19; color: BarStyle.subtext }
                TextInput { id: lq; x: 38; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter; color: BarStyle.text; font.pixelSize: 13; clip: true; selectByMouse: true
                    text: MusicStore.libQuery; onTextChanged: MusicStore.libQuery = text; Keys.onEscapePressed: { text = ""; focus = false } }
                EText { x: 38; anchors.verticalCenter: parent.verticalCenter; visible: lq.text.length === 0; text: "Search in your library"; font.pixelSize: 13; color: BarStyle.subtext }
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 150; height: 36; radius: 18
                color: sortH.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Row { anchors.centerIn: parent; spacing: 8
                    EText { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 13; color: BarStyle.subtext
                        text: MusicStore.libSort === "recent" ? "Recents" : (MusicStore.libSort === "alpha" ? "Alphabetical" : "Creator") }
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "swap_vert"; size: 18; color: BarStyle.subtext } }
                HoverHandler { id: sortH }
                TapHandler { onTapped: MusicStore.libSort = MusicStore.libSort === "recent" ? "alpha" : (MusicStore.libSort === "alpha" ? "creator" : "recent") }
            }
        }

        // the list
        ListView {
            id: list
            x: 6; y: head.height + (MusicStore.libShown ? 92 : 4); width: parent.width - 12; height: parent.height - y - (MusicStore.libShown ? 46 : 8)
            clip: true; spacing: 2; boundsBehavior: Flickable.StopAtBounds
            bottomMargin: 14; topMargin: 2
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: listFade; maskThresholdMin: 0.0; maskSpreadAtMin: 0.0 }
            model: MusicStore.libraryItems
            delegate: Item {
                id: it
                required property var modelData
                required property int index
                readonly property var item: modelData.item
                width: ListView.view.width; height: MusicStore.libShown ? 66 : 72
                readonly property bool playing: MusicStore.ctx?.uri === item.uri
                readonly property bool on: MusicStore.page === modelData.kind && MusicStore.arg?.id === item.id
                Rectangle { anchors.fill: parent; radius: 16
                    color: it.on ? Qt.rgba(1, 1, 1, 0.1) : (itH.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"); Behavior on color { ColorAnimation { duration: 90 } } }
                ClippingRectangle {
                    x: MusicStore.libShown ? 8 : (parent.width - 54) / 2; anchors.verticalCenter: parent.verticalCenter; width: 54; height: 54
                    radius: it.modelData.kind === "artist" ? 27 : 10; color: BarStyle.plate
                    Image { anchors.fill: parent; source: MusicStore.artOf(it.item, false); sourceSize: Qt.size(120, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false }
                    Rectangle { visible: it.playing; anchors.fill: parent; color: "#66000000"
                        BarIcon { anchors.centerIn: parent; name: Playback.isPlaying ? "graphic_eq" : "pause"; size: 24; color: MusicStore.accent } }
                }
                Column { visible: MusicStore.libShown; x: 72; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 134; spacing: 3
                    EText { width: parent.width; elide: Text.ElideRight; text: it.item.name; font.weight: Font.DemiBold; color: it.playing ? MusicStore.accent : BarStyle.text }
                    Row { spacing: 6
                        BarIcon { visible: MusicStore.isPinned(it.item.id); anchors.verticalCenter: parent.verticalCenter; name: "keep"; fill: 1; size: 13; color: MusicStore.accent }
                        EText { width: Math.min(implicitWidth, 230); elide: Text.ElideRight; text: it.modelData.sub; font.pixelSize: 12; color: BarStyle.subtext } } }
                // Spotify's round play button on the right of the row
                Rectangle {
                    id: pb
                    visible: MusicStore.libShown
                    width: 36; height: 36; radius: 18; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: MusicStore.accent; opacity: (itH.hovered || pbH.hovered) ? 1 : 0; scale: pbH.hovered ? 1.08 : 1
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    BarIcon { anchors.centerIn: parent; name: MusicStore.playingContext(it.item.uri) ? "pause" : "play_arrow"; fill: 1; size: 22; color: MusicStore.onAccent }
                    HoverHandler { id: pbH }
                    TapHandler { enabled: pb.opacity > 0.5; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: MusicStore.toggleContext(it.item.uri) }
                }
                HoverHandler { id: itH }
                TapHandler { onTapped: MusicStore.go(it.modelData.kind, it.item) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.menuFor = it.modelData; root.menuY = Math.min(lib.y + list.y + it.y - list.contentY + 20, root.height - 190) } }
            }
        }
        Item { id: listFade; x: list.x; y: list.y; width: list.width; height: list.height; visible: false; layer.enabled: true
            Rectangle { anchors.fill: parent; gradient: Gradient {
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 0.025; color: "#ff000000" }
                GradientStop { position: 0.9; color: "#ff000000" }
                GradientStop { position: 1; color: "#00000000" } } } }
        // hidden ones
        Rectangle {
            visible: MusicStore.libShown
            x: 8; y: parent.height - 44; width: parent.width - 16; height: 36; radius: 18
            color: hidH.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Row { anchors.centerIn: parent; spacing: 8
                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: MusicStore.showHidden ? "visibility" : "visibility_off"; size: 18; color: BarStyle.subtext }
                EText { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 13; color: BarStyle.subtext
                    text: MusicStore.showHidden ? "Back to your library" : (MusicStore.hidden.length > 0 ? MusicStore.hidden.length + " hidden" : "Right-click something to hide it") } }
            HoverHandler { id: hidH }
            TapHandler { onTapped: MusicStore.showHidden = !MusicStore.showHidden }
        }
    }

    // ---- the right-click menu
    MouseArea { anchors.fill: parent; visible: root.menuFor !== null; onClicked: root.menuFor = null; z: 50 }
    Rectangle {
        id: menu
        visible: root.menuFor !== null; z: 51
        x: 70; y: root.menuY; width: 230; height: menuCol.implicitHeight + 16; radius: 18
        color: "#f01a1a1e"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        Column {
            id: menuCol
            x: 8; y: 8; width: parent.width - 16
            Repeater {
                model: [
                    { t: "Open", i: "open_in_new", a: "open" },
                    { t: root.menuFor && MusicStore.isPinned(root.menuFor.item.id) ? "Unpin" : "Pin to the top", i: "keep", a: "pin" },
                    { t: root.menuFor && MusicStore.isHidden(root.menuFor.item.id) ? "Show in library" : "Hide from library", i: "visibility_off", a: "hide" },
                    { t: "Play", i: "play_arrow", a: "play" }
                ]
                delegate: Rectangle {
                    id: mi
                    required property var modelData
                    width: menuCol.width; height: 42; radius: 12; color: miH.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: mi.modelData.i; size: 20; color: BarStyle.text }
                        EText { anchors.verticalCenter: parent.verticalCenter; text: mi.modelData.t; font.weight: Font.Medium } }
                    HoverHandler { id: miH }
                    TapHandler { onTapped: {
                        const e = root.menuFor; root.menuFor = null
                        if (mi.modelData.a === "open") MusicStore.go(e.kind, e.item)
                        else if (mi.modelData.a === "pin") MusicStore.togglePin(e.item.id)
                        else if (mi.modelData.a === "hide") MusicStore.toggleHidden(e.item.id)
                        else MusicApi.play(e.item.uri, true, "")
                    } }
                }
            }
        }
    }
}
