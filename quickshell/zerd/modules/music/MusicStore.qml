pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.bars

// Orbit's state: where you are (with back and forward), what is loaded, what Spotify says is playing, and the
// little things that act on it (heart, trash bin, loop, queue). Nothing here draws.
Singleton {
    id: root

    property bool active: false
    readonly property string home: Quickshell.env("HOME") + "/.local/state/zerd-music"

    // ---- where you are
    property var stack: [{ page: "home", arg: null }]
    property int at: 0
    readonly property string page: root.stack[root.at].page
    readonly property var arg: root.stack[root.at].arg
    readonly property bool canBack: root.at > 0
    readonly property bool canForward: root.at < root.stack.length - 1
    property string query: ""
    // what you searched for before: kept on disk, shown on the Search page as chips
    property var searchHistory: []
    FileView { id: histFile; path: root.home + "/search-history.json"; onLoaded: { try { root.searchHistory = JSON.parse(histFile.text()) } catch (e) {} } }
    Timer { id: histSave; interval: 1600
        onTriggered: {
            const q = root.query.trim()
            if (q.length < 3) return
            root.searchHistory = [q].concat(root.searchHistory.filter(x => x.toLowerCase() !== q.toLowerCase())).slice(0, 8)
            histFile.setText(JSON.stringify(root.searchHistory))
        } }
    onQueryChanged: histSave.restart()
    function clearHistory(): void { root.searchHistory = []; histFile.setText("[]") }
    function go(page: string, arg: var): void {
        const cur = root.stack[root.at]
        if (cur.page === page && (cur.arg?.id ?? "") === (arg?.id ?? "") && page !== "search") return
        const s = root.stack.slice(0, root.at + 1); s.push({ page: page, arg: arg ?? null })
        root.stack = s.slice(-40); root.at = root.stack.length - 1
    }
    function back(): void { if (root.canBack) root.at-- }
    function forward(): void { if (root.canForward) root.at++ }
    property bool immersive: false
    property bool nowOpen: true               // the right-hand "now playing" panel
    // A narrow window (half a screen) drops the side panel and shrinks the library to covers; the saved choices stay as they were.
    property bool narrow: false
    readonly property bool nowShown: nowOpen && !narrow

    // ---- what you have
    property var lists: []
    property var recent: []
    property var savedAlbums: []
    property var followedArtists: []
    property var recentCtx: []                 // context uris, newest first
    // The library column: what to show, how it is sorted, and what you hid.
    property string libChip: "all"             // all | playlists | albums | artists
    property string libSort: "recent"          // recent | alpha | creator
    property string libQuery: ""
    property bool libOpen: true                // full column, or just the covers
    readonly property bool libShown: libOpen && !narrow
    property bool showHidden: false
    property var hidden: []
    function isHidden(id: string): bool { return root.hidden.includes(id) }
    function toggleHidden(id: string): void {
        root.hidden = root.isHidden(id) ? root.hidden.filter(x => x !== id) : root.hidden.concat([id])
        hiddenFile.setText(JSON.stringify(root.hidden))
        root.tell(root.isHidden(id) ? "Hidden from your library" : "Back in your library")
    }
    FileView { id: hiddenFile; path: root.home + "/hidden.json"; onLoaded: { try { root.hidden = JSON.parse(hiddenFile.text()) } catch (e) {} } }
    // the eight tiles at the top of Home: Liked Songs, then where you listened last
    readonly property var quickTiles: {
        const out = [{ kind: "liked", item: { id: "liked", name: "Liked Songs", images: [] } }]
        const pool = []
        for (const l of root.lists) if (l) pool.push({ kind: "playlist", item: l })
        for (const a of root.savedAlbums) pool.push({ kind: "album", item: a })
        for (const a of root.followedArtists) pool.push({ kind: "artist", item: a })
        for (const u of root.recentCtx) { const f = pool.find(x => x.item.uri === u); if (f && out.length < 8 && !root.isHidden(f.item.id)) out.push(f) }
        for (const a of root.recent) if (out.length < 8 && !out.some(x => x.item.id === a.id)) out.push({ kind: "album", item: a })
        for (const l of root.lists) if (l && out.length < 8 && !out.some(x => x.item.id === l.id) && !root.isHidden(l.id)) out.push({ kind: "playlist", item: l })
        return out
    }
    // everything in the library column, sorted and filtered
    readonly property var libraryItems: {
        const all = []
        if (root.libChip === "all" || root.libChip === "playlists") for (const l of root.lists) if (l) all.push({ kind: "playlist", item: l, sub: "Playlist · " + (l.owner?.display_name ?? "") })
        if (root.libChip === "all" || root.libChip === "albums") for (const a of root.savedAlbums) all.push({ kind: "album", item: a, sub: "Album · " + root.artistsOf(a) })
        if (root.libChip === "all" || root.libChip === "artists") for (const a of root.followedArtists) all.push({ kind: "artist", item: a, sub: "Artist" })
        const q = root.libQuery.trim().toLowerCase()
        let out = all.filter(x => (root.showHidden ? root.isHidden(x.item.id) : !root.isHidden(x.item.id)) && (q.length === 0 || x.item.name.toLowerCase().includes(q)))
        const rank = x => { const i = root.recentCtx.indexOf(x.item.uri); return i < 0 ? 999 : i }
        if (root.libSort === "alpha") out.sort((a, b) => a.item.name.localeCompare(b.item.name))
        else if (root.libSort === "creator") out.sort((a, b) => a.sub.localeCompare(b.sub) || a.item.name.localeCompare(b.item.name))
        else out.sort((a, b) => {
            // playing now first, then pinned, then by how recently you listened
            const pa = root.ctx?.uri === a.item.uri ? 0 : 1, pb = root.ctx?.uri === b.item.uri ? 0 : 1
            if (pa !== pb) return pa - pb
            const na = root.isPinned(a.item.id) ? 0 : 1, nb = root.isPinned(b.item.id) ? 0 : 1
            if (na !== nb) return na - nb
            return rank(a) - rank(b)
        })
        return out
    }
    property var topArtistsList: []
    property var topTracksList: []
    property var topAlbums: []
    property string name: ""
    property var me: null
    // what Spotify is playing from (a playlist, an album, an artist): { type, id, uri, name }
    property var ctx: null
    function resolveContext(): void {
        const c = root.player?.context
        if (!c || !c.uri) { root.ctx = null; return }
        if (root.ctx?.uri === c.uri) return
        const m = c.uri.split(":"); const type = m[1], id = m[2]
        const known = type === "playlist" ? root.lists.find(l => l && l.id === id) : null
        root.ctx = { type: type, id: id, uri: c.uri, name: known?.name ?? "" }
        if (!known && (type === "playlist" || type === "album" || type === "artist")) {
            const path = (type === "playlist" ? "/playlists/" : type === "album" ? "/albums/" : "/artists/") + id
            MusicApi.call("GET", path, null, (s, j) => { if (s === 200 && root.ctx?.uri === c.uri) root.ctx = Object.assign({}, root.ctx, { name: j.name, item: j }) })
        } else if (known) root.ctx = Object.assign({}, root.ctx, { item: known })
    }
    function openContext(): void { if (root.ctx && root.ctx.item) root.go(root.ctx.type, root.ctx.item); else if (root.ctx) root.go(root.ctx.type, { id: root.ctx.id, name: root.ctx.name, uri: root.ctx.uri }) }
    property var pinned: []
    // The library lists are kept on disk and reused for 20 minutes, so opening the window costs no requests at all.
    property bool cacheRead: false
    property bool wantLoad: false
    property double cachedAt: 0
    readonly property bool cacheFresh: Date.now() - root.cachedAt < 20 * 60 * 1000
    FileView {
        id: libFile; path: root.home + "/library.json"
        onLoaded: {
            try {
                const c = JSON.parse(libFile.text())
                root.cachedAt = c.t ?? 0
                root.name = c.name ?? ""; root.me = c.me ?? null
                root.lists = c.lists ?? []; root.savedAlbums = c.savedAlbums ?? []; root.followedArtists = c.followedArtists ?? []
                root.recentCtx = c.recentCtx ?? []; root.recent = c.recent ?? []
                root.topArtistsList = c.topArtistsList ?? []; root.topTracksList = c.topTracksList ?? []; root.topAlbums = c.topAlbums ?? []
            } catch (e) {}
            root.cacheRead = true; if (root.wantLoad) { root.wantLoad = false; root.load() }
        }
        onLoadFailed: { root.cacheRead = true; if (root.wantLoad) { root.wantLoad = false; root.load() } }
    }
    Timer { id: saveLib; interval: 2500
        onTriggered: libFile.setText(JSON.stringify({ t: root.cachedAt, name: root.name, me: root.me, lists: root.lists, savedAlbums: root.savedAlbums,
            followedArtists: root.followedArtists, recentCtx: root.recentCtx, recent: root.recent, topArtistsList: root.topArtistsList,
            topTracksList: root.topTracksList, topAlbums: root.topAlbums })) }
    function stash(): void { root.cachedAt = Date.now(); saveLib.restart() }
    function load(force: bool): void {
        if (!MusicApi.signedIn) return
        if (!root.cacheRead) { root.wantLoad = true; return }
        if (!MusicApi.limited && (force === true || !root.cacheFresh)) {
            // the three that fill the sidebar first; the rest a little later, so a restart is never a burst of requests
            MusicApi.playlists(r => { if (r.length > 0) { root.lists = r; root.stash() } })
            MusicApi.savedAlbums(r => { if (r.length > 0) { root.savedAlbums = r; root.stash() } })
            MusicApi.followedArtists(r => { if (r.length > 0) { root.followedArtists = r; root.stash() } })
            lateLoad.restart()
        }
        root.refreshPlayer()
    }
    Timer { id: lateLoad; interval: 6000
        onTriggered: {
            if (MusicApi.limited) return
            MusicApi.call("GET", "/me", null, (s, j) => { if (s === 200) { root.name = j.display_name ?? ""; root.me = j; root.stash() } })
            MusicApi.recentContexts(r => { if (r.length > 0) { root.recentCtx = r; root.stash() } })
            MusicApi.recent(r => {
                const seen = {}; const out = []
                for (const t of r) if (t?.album && !seen[t.album.id]) { seen[t.album.id] = true; out.push(t.album) }
                if (out.length > 0) { root.recent = out; root.stash() }
            })
            MusicApi.topArtists("short_term", r => { if (r.length > 0) { root.topArtistsList = r; root.stash() } })
            MusicApi.topTracks("short_term", r => {
                if (r.length === 0) return
                root.topTracksList = r
                const seen = {}; const out = []
                for (const t of r) if (t.album && !seen[t.album.id]) { seen[t.album.id] = true; out.push(t.album) }
                root.topAlbums = out; root.stash()
            })
        }
    }
    Connections { target: MusicApi; function onSignedInChanged() { if (MusicApi.signedIn && root.active) root.load() } }
    function isPinned(id: string): bool { return root.pinned.includes(id) }
    function togglePin(id: string): void {
        root.pinned = root.isPinned(id) ? root.pinned.filter(x => x !== id) : root.pinned.concat([id])
        pinFile.setText(JSON.stringify(root.pinned))
    }
    FileView { id: pinFile; path: root.home + "/pins.json"; onLoaded: { try { root.pinned = JSON.parse(pinFile.text()) } catch (e) {} } }

    // ---- what Spotify says is playing (polled only while the window is open)
    property var player: null
    readonly property string itemId: root.player?.item?.id ?? ""
    readonly property bool shuffle: root.player?.shuffle_state ?? false
    readonly property string repeat: root.player?.repeat_state ?? "off"
    property int volume: root.player?.device?.volume_percent ?? 50
    readonly property string deviceName: root.player?.device?.name ?? ""
    property bool liked: false
    function refreshPlayer(): void {
        if (EchoPlayer.engine === "soloist") {      // Soloist pushes its state, nothing is polled
            const was = root.itemId
            root.player = SoloistPlayer.shape
            Playback.feed(root.player); root.resolveContext()
            if (root.itemId !== "" && root.itemId !== was) MusicApi.isLiked(root.itemId, v => root.liked = v)
            return
        }
        MusicApi.player(p => {
            const was = root.itemId
            root.player = p
            Playback.feed(p)
            root.resolveContext()
            if (root.itemId !== "" && root.itemId !== was) MusicApi.isLiked(root.itemId, v => root.liked = v)
        })
    }
    Connections { target: SoloistPlayer; function onShapeChanged() { if (EchoPlayer.engine === "soloist") root.refreshPlayer() } }
    Timer { interval: 4000; repeat: true; running: root.active && MusicApi.signedIn && !MusicApi.limited && EchoPlayer.engine !== "soloist"; onTriggered: root.refreshPlayer() }
    function addCurrentToPlaylist(): void {
        const it = root.player?.item
        if (!it || !it.uri) { root.tell("Nothing playing to add"); return }
        root.pickTrack = it
    }
    function toggleLike(): void {
        if (root.itemId === "") return
        root.liked = !root.liked
        MusicApi.setLiked(root.itemId, root.liked)
        root.tell(root.liked ? "Added to Liked Songs" : "Removed from Liked Songs")
    }
    function toggleShuffle(): void { MusicApi.setShuffle(!root.shuffle); root.player = Object.assign({}, root.player, { shuffle_state: !root.shuffle }) }
    function cycleRepeat(): void {
        const next = root.repeat === "off" ? "context" : (root.repeat === "context" ? "track" : "off")
        MusicApi.setRepeat(next); root.player = Object.assign({}, root.player, { repeat_state: next })
    }
    Timer { id: volTimer; interval: 180; property int to: 50; onTriggered: MusicApi.setVolume(to) }
    function setVolume(p: int): void { root.volume = p; volTimer.to = p; volTimer.restart() }

    // ---- words ready before you ask: look them up when the song changes, and for the one after it
    readonly property var mp: Playback.player
    readonly property string trackKey: (root.mp?.trackTitle ?? "") + "|" + (root.mp?.trackArtist ?? "")
    function lyricsNow(): void {
        if (!root.active || !root.mp?.trackTitle) return
        LyricsStore.request(root.mp.trackTitle, root.mp.trackArtist ?? "", root.mp.length ?? 0)
        if (EchoPlayer.engine !== "soloist") MusicApi.playerQueue(q => { const n = (q?.queue ?? [])[0]; if (n) LyricsStore.prefetch(n.name, n.artists?.[0]?.name ?? "", (n.duration_ms ?? 0) / 1000) })
    }
    // with Orbit's own player the queue comes from Soloist itself: look up the next three songs' words ahead of time
    Connections { target: SoloistPlayer
        function onUpcomingChanged() {
            if (!root.active) return
            SoloistPlayer.upcoming.slice(0, 3).forEach(i => LyricsStore.prefetch(i.decorations?.identity?.name ?? "", (i.decorations?.creators?.[0]?.entity ?? i.decorations?.creators?.[0])?.decorations?.identity?.name ?? "", (i.decorations?.playback?.duration_ms ?? 0) / 1000))
        } }
    onTrackKeyChanged: { root.skipping = false; lyricsNow() }
    onActiveChanged: if (root.active) { root.load(); root.lyricsNow() }

    // ---- colour from the cover (set by Backdrop): the accent of the whole app follows what is playing
    property color coverColor: "transparent"
    property real coverLum: 0.3
    property color accent: root.coverColor.a > 0.5 ? root.coverColor : BarStyle.accent
    Behavior on accent { ColorAnimation { duration: 700; easing.type: Easing.InOutSine } }
    readonly property color onAccent: (0.299 * root.accent.r + 0.587 * root.accent.g + 0.114 * root.accent.b) > 0.58 ? "#1a1315" : "#ffffff"

    // ---- small things
    property string note: ""
    function tell(m: string): void { root.note = m; noteTimer.restart() }
    Timer { id: noteTimer; interval: 2400; onTriggered: root.note = "" }
    property var pickTrack: null
    property var trash: []
    function key(title: string, artist: string): string { return (title + "|" + artist).toLowerCase() }
    function trashed(title: string, artist: string): bool { return root.trash.includes(root.key(title, artist)) }
    function toTrash(t: var): void {
        const k = root.key(t.name, (t.artists ?? [])[0]?.name ?? "")
        if (!root.trash.includes(k)) { root.trash = root.trash.concat([k]); trashFile.setText(JSON.stringify(root.trash)) }
        root.tell("Won't play \"" + t.name + "\" again")
        if (Playback.player?.trackTitle === t.name) Playback.next()
    }
    function clearTrash(): void { root.trash = []; trashFile.setText("[]"); root.tell("Trash bin emptied") }
    FileView { id: trashFile; path: root.home + "/trash.json"; onLoaded: { try { root.trash = JSON.parse(trashFile.text()) } catch (e) {} } }
    Timer {
        interval: 600; repeat: true; running: MusicApi.signedIn && root.trash.length > 0 && Playback.isPlaying
        onTriggered: { const p = Playback.player; if (p && root.trashed(p.trackTitle ?? "", (p.trackArtist ?? "").split(",")[0].trim())) Playback.next() }
    }
    property real loopA: -1
    property real loopB: -1
    Timer {
        interval: 200; repeat: true; running: root.loopB > 0 && Playback.isPlaying
        onTriggered: { const p = Playback.player; if (p) { p.positionChanged(); if (p.position >= root.loopB) p.position = Math.max(0, root.loopA) } }
    }
    function shufflePlus(list: var): void {
        root.tell("Shuffling \"" + list.name + "\"…")
        MusicApi.allPlaylistTracks(list.id, tracks => {
            const u = tracks.map(t => t.uri)
            for (let i = u.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); const t = u[i]; u[i] = u[j]; u[j] = t }
            if (u.length > 0) { MusicApi.playUris(u); root.tell("Playing a fresh shuffle") }
        })
    }
    // Skipping: the button answers at once (a pulse and a spinner on the play button) even though the song takes
    // a moment to change; the progress line goes back to the start the instant the new song shows.
    property bool skipping: false
    Timer { id: skipTimer; interval: 2500; onTriggered: root.skipping = false }
    function skip(dir: int): void {
        root.skipping = true; skipTimer.restart()
        if (dir > 0) Playback.next(); else Playback.previous()
    }
    // Play on a playlist or album that is already playing means pause, not start over.
    function playingContext(uri: string): bool { return root.ctx?.uri === uri && Playback.isPlaying }
    function toggleContext(uri: string): void { if (root.ctx?.uri === uri) Playback.toggle(); else MusicApi.play(uri, true, "") }
    function artistsOf(t: var): string { return (t?.artists ?? []).map(a => a.name).join(", ") }
    function artOf(o: var, big: bool): string { const im = o?.album?.images ?? o?.images ?? []; if (im.length === 0) return ""; return big ? im[0].url : im[Math.min(im.length - 1, 1)].url }
    function playItem(item: var, kind: string): void {
        if (kind === "track") MusicApi.play(item.uri, false, "")
        else MusicApi.play(item.uri, true, "")
    }
}
