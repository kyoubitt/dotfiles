pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What is playing, wherever it plays. With the Spotify app, that is the app's MPRIS player. With Orbit's own engine
// (librespot) there is no MPRIS, so the same shape is built from Spotify's player state, with the position carried
// forward locally between polls. Everything in the music window reads this, never MPRIS directly.
Singleton {
    id: root

    readonly property bool viaSoloist: EchoPlayer.engine === "soloist"
    readonly property bool viaApi: (EchoPlayer.engine === "echo" && !MusicApi.limited) || root.viaSoloist
    readonly property var player: root.viaApi ? api : MprisController.activePlayer
    readonly property bool isPlaying: root.viaApi ? api.isPlaying : MprisController.isPlaying

    QtObject {
        id: api
        property string trackTitle: ""
        property string trackArtist: ""
        property string trackArtUrl: ""
        property real length: 0
        property bool isPlaying: false
        property bool feeding: false
        property real position: 0
        // so the bar and other places can use this like an MPRIS player
        readonly property string trackArtists: trackArtist
        function togglePlaying(): void { root.toggle() }
        function next(): void { root.next() }
        function previous(): void { root.previous() }
        property real fed: 0      // the last position we set ourselves: the window also emits positionChanged() just to refresh, which is not a seek
        onPositionChanged: if (!feeding && Math.abs(position - fed) > 0.8) { fed = position; seekTimer.target = position; seekTimer.restart() }
    }
    // a seek by the user: wait a beat so a drag is one request
    Timer { id: seekTimer; interval: 120; property real target: 0
        onTriggered: { if (root.viaSoloist) SoloistPlayer.seek(target * 1000); else { MusicApi.call("PUT", "/me/player/seek?position_ms=" + Math.round(target * 1000), null, null); root.later() } } }
    // between polls the position moves on its own
    Timer { interval: MusicStore.active ? 100 : 1000; repeat: true; running: root.viaApi && api.isPlaying
        onTriggered: {
            api.feeding = true
            // from Soloist's own clock reading, not by adding up ticks (a late tick would drift the lyrics)
            api.position = root.viaSoloist ? Math.min(api.length, (SoloistPlayer.posMs + (SoloistPlayer.speed > 0 ? (Date.now() - SoloistPlayer.posAt) * SoloistPlayer.speed : 0)) / 1000)
                                           : Math.min(api.length, api.position + 0.1)
            api.fed = api.position; api.feeding = false
        } }
    Timer { id: soon; interval: 450; onTriggered: MusicStore.refreshPlayer() }
    function later(): void { soon.restart() }

    // called with every /me/player answer
    function feed(p: var): void {
        const it = p?.item
        if (!it) { api.feeding = true; api.isPlaying = false; api.feeding = false; return }     // nothing live: keep showing the last song
        api.feeding = true
        api.isPlaying = p?.is_playing ?? false
        api.trackTitle = it?.name ?? ""
        api.trackArtist = (it?.artists ?? []).map(a => a.name).join(", ")
        const imgs = it?.album?.images ?? []
        api.trackArtUrl = imgs.length > 0 ? imgs[0].url : ""
        api.length = (it?.duration_ms ?? 0) / 1000
        api.position = (p?.progress_ms ?? 0) / 1000; api.fed = api.position
        root.lastUri = it.uri ?? root.lastUri
        saveLast.restart()
        api.feeding = false
    }

    function ping(): void {}
    // hand the player object to the bar and the lock screen, but only while Orbit is the engine
    readonly property var share: root.viaSoloist ? api : null
    onShareChanged: NowPlaying.orbit = root.share
    Component.onCompleted: NowPlaying.orbit = root.share

    // ---- the last song is remembered, so the window opens on it (paused) and play brings it back where it stopped
    property string lastUri: ""
    property real lastPos: 0
    FileView { id: lastFile; path: Quickshell.env("HOME") + "/.local/state/zerd-music/last.json"
        onLoaded: {
            try {
                const d = JSON.parse(lastFile.text())
                if (api.trackTitle === "" && d.title) {
                    api.feeding = true
                    api.trackTitle = d.title; api.trackArtist = d.artist ?? ""; api.trackArtUrl = d.art ?? ""; api.length = d.length ?? 0
                    api.position = d.position ?? 0; api.fed = api.position; api.isPlaying = false
                    api.feeding = false
                    root.lastUri = d.uri ?? ""; root.lastPos = d.position ?? 0
                }
            } catch (e) {}
        } }
    // while a song plays the place in it is saved every few seconds, so a restart can pick up where it was
    Timer { interval: 5000; repeat: true; running: root.viaApi && api.isPlaying; onTriggered: saveLast.restart() }
    Timer { id: saveLast; interval: 3000
        onTriggered: if (api.trackTitle !== "") lastFile.setText(JSON.stringify({ uri: root.lastUri, title: api.trackTitle, artist: api.trackArtist, art: api.trackArtUrl, length: api.length, position: api.position })) }
    Timer { id: resumeAt; interval: 1800; property real ms: 0; onTriggered: if (ms > 3000) SoloistPlayer.seek(ms) }
    function toggle(): void {
        if (!root.viaApi) { MprisController.togglePlaying(); return }
        const was = api.isPlaying
        api.isPlaying = !was
        if (root.viaSoloist && SoloistPlayer.shape === null && root.lastUri !== "") {
            SoloistPlayer.ready(() => { SoloistPlayer.play(root.lastUri); resumeAt.ms = api.position * 1000; resumeAt.restart() }); return
        }
        if (root.viaSoloist) { if (was) SoloistPlayer.pause(); else SoloistPlayer.ready(() => SoloistPlayer.resume()); return }
        const go = () => { MusicApi.call("PUT", was ? "/me/player/pause" : "/me/player/play", null, null); root.later() }
        if (was) go(); else EchoPlayer.ready(go)
    }
    function next(): void { if (root.viaSoloist) SoloistPlayer.next(); else if (root.viaApi) { MusicApi.call("POST", "/me/player/next", null, null); root.later() } else MprisController.next() }
    function previous(): void { if (root.viaSoloist) SoloistPlayer.previous(); else if (root.viaApi) { MusicApi.call("POST", "/me/player/previous", null, null); root.later() } else MprisController.previous() }
}
