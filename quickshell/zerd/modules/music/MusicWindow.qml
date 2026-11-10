pragma ComponentBehavior: Bound

import QtQuick
import qs
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.bars

// Orbit, a QML client for Spotify, in its own window. It drives your Spotify (Premium): Spotify plays, this looks
// and controls. `ipc call music toggle|open|close|page <name>`.
Scope {
    id: root

    property bool open: false
    Connections { target: GlobalStates; function onMusicRequestChanged() { root.open = true; focusIt.tries = 0; focusIt.restart() } }

    IpcHandler {
        target: "music"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function launch(): void { GlobalStates.musicRequest++ }      // what the app menu does
        function close(): void { root.open = false }
        function goto(kind: string, id: string, name: string): void { root.open = true; MusicStore.go(kind, { id: id, name: name, uri: "spotify:" + kind + ":" + id }) }
        function playpause(): void { Playback.toggle() }
        function next(): void { Playback.next() }
        function prev(): void { Playback.previous() }
        function seek(seconds: real): void { const p = Playback.player; if (p) p.position = seconds }
        function volume(percent: int): void { MusicStore.setVolume(percent) }
        function page(name: string): void { root.open = true; if (name === "immersive") MusicStore.immersive = true; else MusicStore.go(name, null) }
    }
    // A new window can land on a workspace you are not looking at (the app menu is a layer, not a window), so once it
    // exists it is brought into focus, which also switches to its workspace.
    // The window belongs to the shell, so a shell restart closes it. It writes down that it is open (with the time, a few
    // seconds apart), and a shell that starts within half a minute of that opens it again: restarts no longer hide it.
    FileView {
        id: openFile
        path: Quickshell.env("HOME") + "/.local/state/zerd-music/open.json"
        onLoaded: { try { const d = JSON.parse(openFile.text()); if (d.open === true && Date.now() - (d.t ?? 0) < 30000) root.open = true } catch (e) {} }
    }
    function noteOpen(): void { openFile.setText(JSON.stringify({ open: root.open, t: Date.now() })) }
    Timer { interval: 4000; repeat: true; running: root.open; onTriggered: root.noteOpen() }
    // A timeline of what the compositor does with the window (opened, moved to another workspace, lost focus, closed),
    // written to ~/.cache/orbit-watch.log while the window is open: read it when the window seems to vanish.
    Process { running: root.open; command: ["python3", "-I", Quickshell.shellPath("scripts/music/orbit-watch.py")] }
    Timer {
        id: focusIt; interval: 300; repeat: true; property int tries: 0
        onTriggered: {
            const w = (NiriService.windows ?? []).find(x => x.title === "Orbit")
            if (w) { Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(w.id)]); running = false }
            else if (++tries > 10) running = false
        }
    }
    onOpenChanged: { root.noteOpen(); console.log("[orbit-win] open=" + root.open + " at " + new Date().toISOString().slice(11, 23)); if (root.open) { focusIt.tries = 0; focusIt.restart() } MusicStore.active = root.open; if (!root.open) MusicStore.immersive = false }

    LazyLoader {
        active: root.open
        component: FloatingWindow {
            id: win
            title: "Orbit"
            implicitWidth: 1220
            implicitHeight: 780
            color: "#0a0a0e"
            visible: true
            onVisibleChanged: { console.log("[orbit-win] visible=" + visible); if (!visible) root.open = false }

            // ---- sign-in
            Item {
                anchors.fill: parent; visible: !MusicApi.signedIn
                Column {
                    anchors.centerIn: parent; width: 440; spacing: 14
                    Image { width: 72; height: 72; source: Qt.resolvedUrl("../../assets/icons/orbit.svg"); sourceSize: Qt.size(144, 144); smooth: true }
                    EText { text: "Orbit"; font.pixelSize: 30; font.weight: Font.DemiBold }
                    EText { width: parent.width; wrapMode: Text.Wrap; color: BarStyle.subtext
                        text: "A QML client for Spotify. Search, playlists and your stats, driving your own Spotify (Premium). Make a free Spotify app once:\n1. developer.spotify.com/dashboard > Create app\n2. Redirect URI: http://127.0.0.1:8898/callback\n3. Tick Web API, then paste its Client ID below." }
                    Rectangle {
                        width: parent.width; height: 44; radius: 23; color: BarStyle.plate; border.width: 1; border.color: idIn.activeFocus ? MusicStore.accent : BarStyle.border
                        TextInput {
                            id: idIn
                            x: 18; width: parent.width - 36; anchors.verticalCenter: parent.verticalCenter
                            color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true; selectByMouse: true
                            text: MusicApi.clientId
                            onEditingFinished: Config.setNestedValue("music.clientId", text.trim())
                        }
                        EText { x: 18; anchors.verticalCenter: parent.verticalCenter; visible: idIn.text.length === 0; text: "Client ID"; color: BarStyle.subtext }
                    }
                    Pill { text: MusicApi.busy ? "Waiting…" : "Sign in"; onTapped: { Config.setNestedValue("music.clientId", idIn.text.trim()); MusicApi.signIn() } }
                    EText { visible: MusicApi.status.length > 0; width: parent.width; wrapMode: Text.Wrap; text: MusicApi.status; color: BarStyle.danger }
                }
            }

            // ---- the app
            Shell { visible: MusicApi.signedIn; onOpenImmersive: MusicStore.immersive = true }

            // full-window player, fading and rising over everything
            Loader {
                anchors.fill: parent
                active: MusicStore.immersive && MusicApi.signedIn
                sourceComponent: Immersive { onClosed: MusicStore.immersive = false }
                opacity: active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            // ---- add to a playlist: a sheet over everything
            Rectangle {
                anchors.fill: parent; visible: MusicStore.pickTrack !== null; color: "#99000000"
                TapHandler { onTapped: MusicStore.pickTrack = null }
                Rectangle {
                    anchors.centerIn: parent; width: 400; height: Math.min(parent.height - 140, 76 + pickList.contentHeight); radius: 30
                    color: BarStyle.surface; border.width: 1; border.color: BarStyle.border
                    EText { x: 26; y: 22; text: "Add to a playlist"; font.pixelSize: 19; font.weight: Font.Bold }
                    ListView {
                        id: pickList
                        x: 12; y: 64; width: parent.width - 24; height: parent.height - 76; clip: true; boundsBehavior: Flickable.StopAtBounds
                        model: MusicStore.lists.filter(l => l)
                        delegate: Item {
                            id: pk
                            required property var modelData
                            width: pickList.width; height: 48
                            Rectangle { anchors.fill: parent; radius: 17; color: pkHov.hovered ? BarStyle.plateHover : "transparent" }
                            EText { x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32; elide: Text.ElideRight; text: pk.modelData.name; font.weight: Font.Medium }
                            HoverHandler { id: pkHov }
                            TapHandler { onTapped: {
                                const t = MusicStore.pickTrack; MusicStore.pickTrack = null
                                MusicApi.addToPlaylist(pk.modelData.id, t.uri, ok => MusicStore.tell(ok ? "Added to " + pk.modelData.name : "Couldn't add it (is it your playlist?)"))
                            } }
                        }
                    }
                }
            }

            // ---- a short message
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 112 }
                width: noteText.implicitWidth + 44; height: 44; radius: 23
                color: MusicStore.accent; opacity: MusicStore.note.length > 0 ? 1 : 0; visible: opacity > 0.01
                scale: MusicStore.note.length > 0 ? 1 : 0.9
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.45 } }
                EText { id: noteText; anchors.centerIn: parent; text: MusicStore.note; font.weight: Font.Medium; color: MusicStore.onAccent }
            }

            // ---- keys: space, N, P, F for the full player, / to search
            Item {
                anchors.fill: parent; focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space) Playback.toggle()
                    else if (event.key === Qt.Key_N) Playback.next()
                    else if (event.key === Qt.Key_P) Playback.previous()
                    else if (event.key === Qt.Key_F) MusicStore.immersive = !MusicStore.immersive
                    else if (event.key === Qt.Key_Slash) MusicStore.go("search", null)
                    else if (event.key === Qt.Key_H) MusicStore.back()
                    else if (event.key === Qt.Key_L) MusicStore.forward()
                    else if (event.key === Qt.Key_Escape) { if (MusicStore.immersive) MusicStore.immersive = false; else root.open = false }
                    else return
                    event.accepted = true
                }
            }
        }
    }
}
