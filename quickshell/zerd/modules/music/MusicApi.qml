pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The Spotify Web API for the shell's music client. Sign-in and token refresh are done by scripts/music/auth.py
// (PKCE, no client secret); this only reads the saved access token and talks to the API. Nothing here is
// written to the repo: the client ID is in the user's own config, the tokens in ~/.local/state/zerd-music.
Singleton {
    id: root

    readonly property string clientId: Config.options?.music?.clientId ?? ""
    readonly property string script: Quickshell.shellPath("scripts/music/auth.py")
    property string token: ""
    property double expiresAt: 0
    property bool hasTokens: false
    property string status: ""            // last sign-in message, for the sign-in screen
    property bool busy: false
    readonly property bool signedIn: root.hasTokens && root.token.length > 0

    FileView {
        id: tokenFile
        path: Quickshell.env("HOME") + "/.local/state/zerd-music/tokens.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(tokenFile.text()); root.token = d.access_token ?? ""; root.expiresAt = d.expires_at ?? 0; root.hasTokens = true } catch (e) {} }
        onLoadFailed: root.hasTokens = false
    }

    function signIn(): void {
        if (root.clientId.length === 0 || loginProc.running) return
        root.status = "Waiting for the browser…"; root.busy = true
        loginProc.command = ["python3", "-I", root.script, "login", root.clientId]; loginProc.running = true
    }
    function signOut(): void {
        Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.local/state/zerd-music/tokens.json"])
        root.token = ""; root.hasTokens = false; root.status = ""
    }
    Process {
        id: loginProc
        stdout: StdioCollector { onStreamFinished: { root.busy = false; root.status = text.trim() === "ok" ? "" : text.trim(); tokenFile.reload() } }
    }

    // Refreshes when the token is about to expire, then runs what was waiting.
    property var waiting: []
    function withToken(run: var): void {
        if (Date.now() / 1000 < root.expiresAt) { run(); return }
        root.waiting.push(run)
        if (!refreshProc.running) { refreshProc.command = ["python3", "-I", root.script, "refresh", root.clientId]; refreshProc.running = true }
    }
    Process {
        id: refreshProc
        stdout: StdioCollector { onStreamFinished: {
            tokenFile.reload()
            const w = root.waiting; root.waiting = []
            if (text.trim() === "ok") w.forEach(f => Qt.callLater(f))
            else { root.status = text.trim(); root.hasTokens = false }
        } }
    }

    // One request. `done(status, json)`; a 401 refreshes once and tries again.
    // Spotify's rate limit: a 429 says how long to stay quiet. Until then nothing is sent, and the window falls back to
    // the Spotify app's own media controls.
    property double blockedUntil: 0
    // remembered across reloads, so a restart never pokes a limit that is still on
    FileView { id: limitFile; path: Quickshell.env("HOME") + "/.local/state/zerd-music/limit.json"
        onLoaded: { try { const d = JSON.parse(limitFile.text()); const t = (d.cid === root.clientId) ? (d.until ?? 0) : 0     // a limit belongs to one app: a new Client ID starts clean
                if (t > root.blockedUntil) { root.blockedUntil = t; root.limitTick++ } } catch (e) {} } }
    property int limitTick: 0
    readonly property bool limited: { root.limitTick; return Date.now() < root.blockedUntil }
    Timer { interval: 30000; repeat: true; running: root.blockedUntil > 0; onTriggered: root.limitTick++ }
    // Reads go out one every 220 ms instead of in a burst (a page load used to fire a dozen at once); writes go at once.
    property var _q: []
    Timer { id: pace; interval: 90; repeat: true; running: root._q.length > 0
        onTriggered: { const f = root._q.shift(); if (f) f(); if (root._q.length === 0) pace.stop() } }
    function call(method: string, path: string, body: var, done: var): void {
        if (method === "GET" && !path.includes("/me/player")) { root._q.push(() => root.callNow(method, path, body, done)); pace.running = true; return }
        root.callNow(method, path, body, done)
    }
    // ---- saved copies: every read that works is kept on disk, so a limit or no network never means an empty page
    readonly property string pagesDir: Quickshell.env("HOME") + "/.local/state/zerd-music/pages"
    property double epoch: 0                       // a change you made (add to playlist, follow...) makes older saved copies stale
    property bool staleServed: false
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.pagesDir])
    Component { id: wComp; FileView { property string payload: ""; Component.onCompleted: setText(payload) } }
    Component { id: rComp
        Process {
            id: rp
            property var cb: null
            stdout: StdioCollector { onStreamFinished: { let d = null; try { d = JSON.parse(text) } catch (e) {} rp.cb(d); rp.destroy() } }
        } }
    function diskWrite(key: string, obj: var): void {
        const f = wComp.createObject(root, { path: root.pagesDir + "/" + key + ".json", payload: JSON.stringify({ t: Date.now(), j: obj }) })
        if (f) f.destroy(4000)
    }
    function diskRead(key: string, cb: var): void {
        const p = rComp.createObject(root, { command: ["cat", root.pagesDir + "/" + key + ".json"], cb: cb })
        if (p) p.running = true
    }
    // ---- while Spotify limits the app: a playlist's first ~100 songs come from its public embed page (no login, no quota)
    function embedTracks(path: string, cb: var): void {
        const m = /^\/playlists\/([A-Za-z0-9]+)\/items/.exec(path)
        if (!m) { cb(null); return }
        if (path.includes("offset=")) { cb({ items: [], next: null, total: 0, partial: true }); return }     // the embed page has only the first songs
        const x = new XMLHttpRequest()
        x.open("GET", "https://open.spotify.com/embed/playlist/" + m[1])
        x.onreadystatechange = () => {
            if (x.readyState !== 4) return
            try {
                const r = /<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/.exec(x.responseText)
                const e = JSON.parse(r[1]).props.pageProps.state.data.entity
                const cover = e.coverArt?.sources?.[0]?.url ?? ""
                const items = (e.trackList ?? []).filter(t => t?.uri).map(t => ({ added_at: null, item: {
                    id: t.uri.split(":")[2], uri: t.uri, type: "track", name: t.title, duration_ms: t.duration, explicit: t.isExplicit === true,
                    artists: (t.subtitle ?? "").split(/,\s*/).filter(n => n).map(n => ({ name: n })), album: { name: "", images: cover ? [{ url: cover }] : [] } } }))
                cb({ items: items, next: null, total: items.length, partial: true })
            } catch (err) { cb(null) }
        }
        x.send()
    }
    // search over what is already on this machine (library lists and every page opened or saved), for when Spotify cannot be asked
    function localSearch(q: string): var {
        const n = q.toLowerCase()
        const has = o => (o?.name ?? "").toLowerCase().includes(n)
        const trackSeen = {}, tracks = []
        for (const k in root._memo) for (const i of (root._memo[k]?.j?.items ?? [])) {
            const t = i?.item ?? i?.track ?? i
            if (t?.uri && !trackSeen[t.uri] && (has(t) || (t.artists ?? []).some(a => has(a)))) { trackSeen[t.uri] = true; tracks.push(t) }
        }
        return { local: true, tracks: { items: tracks.slice(0, 10) }, artists: { items: MusicStore.followedArtists.filter(has).slice(0, 10) },
                 albums: { items: MusicStore.savedAlbums.filter(has).slice(0, 10) }, playlists: { items: MusicStore.lists.filter(has).slice(0, 10) } }
    }
    function callNow(method: string, path: string, body: var, done: var): void {
        const cacheable = method === "GET" && !path.includes("/me/player") && !path.includes("/me/tracks/contains")
        if (method !== "GET" && !path.includes("/me/player")) { root._memo = ({}); root.epoch = Date.now() }
        if (!cacheable) { if (Date.now() < root.blockedUntil) { if (done) done(429, null); return } root.net(method, path, body, done, false, "", null); return }
        const hit = root._memo[path]
        if (hit && Date.now() - hit.t < 300000) { if (done) { const j = hit.j; Qt.callLater(() => done(200, j)) } return }
        const key = Qt.md5(path)
        root.diskRead(key, d => {
            // a saved copy under six hours old is as good as asking again
            if (d && !d.j?.partial && Date.now() - d.t < 6 * 3600000 && d.t > root.epoch) { root._memo[path] = d; if (done) done(200, d.j); return }
            if (Date.now() < root.blockedUntil) {
                if (d) { root.staleServed = true; if (done) done(200, d.j); return }
                root.embedTracks(path, j => { if (j) { root.staleServed = true; root.diskWrite(key, j); if (done) done(200, j) } else if (done) done(429, null) })
                return
            }
            root.net(method, path, body, done, true, key, d)
        })
    }
    function net(method: string, path: string, body: var, done: var, cacheable: bool, key: string, saved: var): void {
        console.log("[orbit-api]", method, path.split("?")[0])
        root.withToken(() => {
            const x = new XMLHttpRequest()
            x.open(method, path.startsWith("http") ? path : "https://api.spotify.com/v1" + path)
            x.setRequestHeader("Authorization", "Bearer " + root.token)
            if (body) x.setRequestHeader("Content-Type", "application/json")
            x.onreadystatechange = () => {
                if (x.readyState !== 4) return
                let j = null
                try { j = x.responseText.length > 0 ? JSON.parse(x.responseText) : null } catch (e) {}
                if (x.status === 429) {
                    const secs = parseInt(x.getResponseHeader("Retry-After") ?? "30") || 30
                    root.blockedUntil = Date.now() + secs * 1000; root.limitTick++; limitFile.setText(JSON.stringify({ until: root.blockedUntil, cid: root.clientId }))
                    MusicStore.tell("Spotify is limiting requests, back in " + (secs >= 3600 ? Math.round(secs / 360) / 10 + " h" : Math.ceil(secs / 60) + " min"))
                }
                if (x.status === 401 && !root._retrying) { root._retrying = true; root.expiresAt = 0; root.call(method, path, body, done); root._retrying = false; return }
                if (cacheable && x.status === 200 && j) { const d = { t: Date.now(), j: j }; root._memo[path] = d; root.trimMemo(); root.diskWrite(key, j); root.staleServed = false }
                else if (cacheable && x.status !== 200 && saved) { root.staleServed = true; if (done) done(200, saved.j); return }
                else if (cacheable && x.status !== 200) { root.embedTracks(path, e => { if (e) { root.staleServed = true; root.diskWrite(key, e); if (done) done(200, e) } else if (done) done(x.status, j) }); return }
                if (done) done(x.status, j)
            }
            x.send(body ? JSON.stringify(body) : undefined)
        })
    }
    property bool _retrying: false
    property var _memo: ({})
    // The answers kept in memory are capped, oldest first, so browsing for hours does not pile them up.
    function trimMemo(): void {
        const ks = Object.keys(root._memo)
        if (ks.length <= 60) return
        ks.sort((x, y) => (root._memo[x]?.t ?? 0) - (root._memo[y]?.t ?? 0))
        for (const k of ks.slice(0, ks.length - 60)) delete root._memo[k]
    }
    function forget(): void { root._memo = ({}) }

    function search(q: string, done: var): void {
        if (root.limited) { done(root.localSearch(q)); return }
        root.call("GET", "/search?type=track,artist,album,playlist&limit=10&q=" + encodeURIComponent(q), null, (s, j) => done(s === 200 ? j : null))
    }
    function playlists(done: var): void { root.call("GET", "/me/playlists?limit=50", null, (s, j) => done(s === 200 ? (j.items ?? []) : [])) }
    function playlistTracks(id: string, done: var): void { root.call("GET", "/playlists/" + id + "/items?limit=100", null, (s, j) => done(s === 200 ? (j.items ?? []).map(i => i.item ?? i.track).filter(t => t) : [])) }
    function savedAlbums(done: var): void { root.call("GET", "/me/albums?limit=50", null, (s, j) => done(s === 200 ? (j.items ?? []).map(i => i.album).filter(a => a) : [])) }
    function followedArtists(done: var): void { root.call("GET", "/me/following?type=artist&limit=50", null, (s, j) => done(s === 200 ? (j.artists?.items ?? []) : [])) }
    // the places you listened from lately (playlists, albums, artists), newest first
    function recentContexts(done: var): void {
        root.call("GET", "/me/player/recently-played?limit=50", null, (s, j) => {
            const out = []; const seen = {}
            for (const i of (s === 200 ? (j.items ?? []) : [])) { const u = i.context?.uri; if (u && !seen[u]) { seen[u] = true; out.push(u) } }
            done(out)
        })
    }
    function recent(done: var): void { root.call("GET", "/me/player/recently-played?limit=20", null, (s, j) => done(s === 200 ? (j.items ?? []).map(i => i.track) : [])) }
    function topTracks(range: string, done: var): void { root.call("GET", "/me/top/tracks?limit=20&time_range=" + range, null, (s, j) => done(s === 200 ? (j.items ?? []) : [])) }
    function topArtists(range: string, done: var): void { root.call("GET", "/me/top/artists?limit=20&time_range=" + range, null, (s, j) => done(s === 200 ? (j.items ?? []) : [])) }

    // Plays a track or a whole playlist/album; with no device awake, wakes the first one it can find.
    function play(uri: string, isContext: bool, offsetUri: string): void {
        EchoPlayer.ready(() => root.playNow(uri, isContext, offsetUri))
    }
    function playNow(uri: string, isContext: bool, offsetUri: string): void {
        if (EchoPlayer.engine === "soloist") { SoloistPlayer.play(isContext && offsetUri ? offsetUri : uri); return }
        const body = isContext ? (offsetUri ? { context_uri: uri, offset: { uri: offsetUri } } : { context_uri: uri }) : { uris: [uri] }
        root.call("PUT", "/me/player/play", body, (s, j) => {
            if (s === 404) root.call("GET", "/me/player/devices", null, (s2, j2) => {
                const d = (j2?.devices ?? [])[0]
                if (d) root.call("PUT", "/me/player", { device_ids: [d.id], play: false }, () => root.call("PUT", "/me/player/play?device_id=" + d.id, body, null))
                else root.status = "Open Spotify first (or start the Zerd player) so there is a device to play on"
            })
        })
    }
    // Every track of a playlist (the API hands out 100 at a time).
    function allPlaylistTracks(id: string, done: var): void {
        const out = []
        const page = (url) => root.call("GET", url, null, (s, j) => {
            if (s !== 200) { done(out); return }
            for (const i of (j.items ?? [])) { const t = i.item ?? i.track; if (t && t.uri && !t.is_local) out.push(t) }
            if (j.next && out.length < 1000) page(j.next); else done(out)
        })
        page("/playlists/" + id + "/items?limit=100")
    }
    function playUris(uris: var): void { EchoPlayer.ready(() => root.playUrisNow(uris)) }
    function playUrisNow(uris: var): void {
        if (EchoPlayer.engine === "soloist") { SoloistPlayer.playMany(uris); return }
        root.call("PUT", "/me/player/play", { uris: uris.slice(0, 100) }, (s) => {
            if (s === 404) root.call("GET", "/me/player/devices", null, (s2, j2) => {
                const d = (j2?.devices ?? [])[0]
                if (d) root.call("PUT", "/me/player", { device_ids: [d.id], play: false }, () => root.call("PUT", "/me/player/play?device_id=" + d.id, { uris: uris.slice(0, 100) }, null))
            })
        })
    }
    // ---- details
    function playlist(id: string, done: var): void { root.call("GET", "/playlists/" + id, null, (s, j) => done(s === 200 ? j : null)) }
    // `partial(list)` is called as pages arrive, so the first hundred songs show at once. The first page says how many
    // songs there are, and the other pages are then asked for together instead of one after the other.
    function playlistItems(id: string, done: var, partial: var): void {
        const base = "/playlists/" + id + "/items?limit=100"
        const pagesOf = {}
        const toTracks = j => (j?.items ?? []).map(i => { const t = i.item ?? i.track; return (t && t.uri && t.type !== "episode") ? Object.assign({ added_at: i.added_at }, t) : null }).filter(t => t)
        const assemble = (count) => { let out = []; for (let k = 0; k < count; k++) { if (!pagesOf[k]) break; out = out.concat(pagesOf[k]) } return out }
        root.call("GET", base, null, (s, j) => {
            if (s !== 200) { done([]); return }
            pagesOf[0] = toTracks(j)
            const total = Math.min(j?.total ?? 0, 1000)
            const count = Math.max(1, Math.ceil(total / 100))
            if (count === 1) { done(assemble(1)); return }
            if (partial) partial(assemble(1))
            let got = 1
            for (let k = 1; k < count; k++) {
                root.call("GET", base + "&offset=" + (k * 100), null, (s2, j2) => {
                    pagesOf[k] = s2 === 200 ? toTracks(j2) : []
                    got++
                    if (got < count) { if (partial) partial(assemble(count)) } else done(assemble(count))
                })
            }
        })
    }
    function album(id: string, done: var): void {
        root.call("GET", "/albums/" + id, null, (s, j) => {
            if (s !== 200) { done(null, []); return }
            const info = { id: j.id, name: j.name, uri: j.uri, images: j.images, artists: j.artists, release_date: j.release_date }
            done(j, (j.tracks?.items ?? []).map(t => Object.assign({}, t, { album: info })))
        })
    }
    function artist(id: string, done: var): void { root.call("GET", "/artists/" + id, null, (s, j) => done(s === 200 ? j : null)) }
    function artistTop(id: string, done: var): void { root.call("GET", "/artists/" + id + "/top-tracks?market=from_token", null, (s, j) => done(s === 200 ? (j.tracks ?? []) : null)) }
    function artistAlbums(id: string, done: var): void { root.call("GET", "/artists/" + id + "/albums?include_groups=album,single&limit=20", null, (s, j) => done(s === 200 ? (j.items ?? []) : [])) }
    function liked(done: var): void {
        const out = []
        const page = (url) => root.call("GET", url, null, (s, j) => {
            if (s !== 200) { done(out, 0); return }
            for (const i of (j.items ?? [])) if (i.track) out.push(i.track)
            if (j.next && out.length < 300) page(j.next); else done(out, j.total ?? out.length)
        })
        page("/me/tracks?limit=50")
    }
    function isLiked(id: string, done: var): void { root.call("GET", "/me/tracks/contains?ids=" + id, null, (s, j) => done(s === 200 && j && j[0] === true)) }
    function setLiked(id: string, on: bool): void { root.call(on ? "PUT" : "DELETE", "/me/tracks?ids=" + id, null, null) }
    function newPlaylist(name: string, done: var): void {
        root.call("GET", "/me", null, (s, me) => { if (s !== 200) { done(null); return }
            root.call("POST", "/users/" + me.id + "/playlists", { name: name, public: false }, (s2, j) => done(s2 < 300 ? j : null)) })
    }
    // ---- playback state and controls (the Spotify Connect side)
    function player(done: var): void { root.call("GET", "/me/player", null, (s, j) => done(s === 200 ? j : null)) }
    function playerQueue(done: var): void {
        if (EchoPlayer.engine === "soloist") { done({ queue: SoloistPlayer.upcoming.map(i => SoloistPlayer.asTrack(i)) }); return }     // from Soloist itself, no request
        root.call("GET", "/me/player/queue", null, (s, j) => done(s === 200 ? j : null))
    }
    function devices(done: var): void { root.call("GET", "/me/player/devices", null, (s, j) => done(s === 200 ? (j.devices ?? []) : [])) }
    function transfer(id: string): void { root.call("PUT", "/me/player", { device_ids: [id], play: true }, null) }
    function setShuffle(on: bool): void { if (EchoPlayer.engine === "soloist") { SoloistPlayer.setShuffle(on); return }; root.call("PUT", "/me/player/shuffle?state=" + on, null, null) }
    function setRepeat(mode: string): void { if (EchoPlayer.engine === "soloist") { SoloistPlayer.setRepeat(mode === "track" ? "track" : (mode === "context" ? "context" : "off")); return }; root.call("PUT", "/me/player/repeat?state=" + mode, null, null) }
    function setVolume(p: int): void { if (EchoPlayer.engine === "soloist") { SoloistPlayer.setVolume(Math.max(0, Math.min(100, p))); return }; root.call("PUT", "/me/player/volume?volume_percent=" + Math.max(0, Math.min(100, p)), null, null) }
    function addToPlaylist(playlistId: string, uri: string, done: var): void { root.call("POST", "/playlists/" + playlistId + "/items", { uris: [uri] }, (s) => { if (done) done(s < 300) }) }
    function queue(uri: string): void { root.call("POST", "/me/player/queue?uri=" + encodeURIComponent(uri), null, null) }
}
