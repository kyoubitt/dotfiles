pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics for the song that is playing. Tries lrclib (synced, line by line), then lrclib's search, then lyrics.ovh
// (plain text). Whatever is found is kept in ~/.cache/echo/lyrics.json, so a song never needs the network twice
// and still has its words when a service is down.
Singleton {
    id: root

    property var lines: []              // [{ t: seconds, s: text }]; t is -1 when the words are not timed
    property bool synced: false
    property string state: "none"       // loading | ok | none | down
    property string key: ""
    property string source: ""         // where the words came from
    property var cache: ({})
    property real secs: 0
    property bool estimated: false      // plain words spread over the song so lines can be clicked

    function keyOf(title: string, artist: string): string { return (title + "|" + artist.split(",")[0].trim()).toLowerCase() }

    function parseLrc(raw: string): var {
        const out = []
        for (const line of raw.split("\n")) {
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g
            const text = line.replace(/\[[^\]]*\]/g, "").trim()
            let m, any = false
            while ((m = re.exec(line)) !== null) { out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), s: text }); any = true }
        }
        out.sort((a, b) => a.t - b.t)
        return out
    }
    function parsePlain(raw: string): var {
        return raw.split("\n").map(l => l.trim()).filter((l, i, a) => l.length > 0 || (i > 0 && a[i - 1].length > 0)).map(l => ({ t: -1, s: l }))
    }
    function set(k: string, lines: var, synced: bool, save: bool, source: string): void {
        if (root.key !== k) return
        root.source = source
        let shown = lines, sync = synced, est = false
        if (!synced && lines.length > 0 && root.secs > 20) { shown = root.estimate(lines, root.secs); sync = true; est = true }
        root.estimated = est
        root.lines = shown; root.synced = sync; root.state = lines.length > 0 ? "ok" : "none"
        if (save && lines.length > 0) {
            root.cache[k] = { synced: synced, lines: lines, source: source }
            const keys = Object.keys(root.cache)
            if (keys.length > 400) delete root.cache[keys[0]]
            file.setText(JSON.stringify(root.cache))
        }
    }

    // Words with no timing: spread them over the song by length, so the list follows along roughly and a line can be
    // clicked to jump there. Credit lines ("Writers: ...") are dropped.
    function estimate(lines: var, secs: real): var {
        const keep = lines.filter(l => !/^(producers?|writers?|written by|lyrics by|composer)s?\s*:/i.test(l.s))
        let total = 0
        for (const l of keep) if (l.s.length > 0) total += l.s.length + 12
        const lead = Math.min(14, secs * 0.07), span = Math.max(10, secs - lead - Math.min(14, secs * 0.07))
        let acc = 0
        return keep.map(l => { const t = lead + (total > 0 ? acc / total : 0) * span; if (l.s.length > 0) acc += l.s.length + 12; return { t: t, s: l.s } })
    }

    function get(url: string, done: var): void {
        const x = new XMLHttpRequest()
        x.open("GET", url)
        x.timeout = 4000
        x.onreadystatechange = () => { if (x.readyState === 4) { let j = null; try { j = JSON.parse(x.responseText) } catch (e) {} done(x.status, j) } }
        x.ontimeout = () => done(0, null)
        x.send()
    }

    // All four sources are asked at once, each with a short timeout. A timed answer wins the moment it arrives;
    // plain words are shown if nothing timed turns up within a moment, and swapped for timed ones if those come later.
    property var tried: ({})
    function run(k: string, title: string, artist: string, secs: real, live: bool): void {
        const a1 = artist.split(",")[0].trim()
        const job = { best: null, left: 4, shownPlain: false }
        const offer = (rank, lines, synced, source) => {
            if (lines.length === 0) return
            if (!job.best || rank > job.best.rank) job.best = { rank: rank, lines: lines, synced: synced, source: source }
            if (synced && rank >= 2) finish()
            else if (live && !job.shownPlain && root.key === k && root.lines.length === 0) { job.shownPlain = true; root.set(k, lines, synced, false, source) }
        }
        let finished = false
        const finish = () => {
            if (finished || !job.best) return
            finished = true
            const bst = job.best
            if (live) root.set(k, bst.lines, bst.synced, true, bst.source)
            else { root.cache[k] = { synced: bst.synced, lines: bst.lines, source: bst.source }; file.setText(JSON.stringify(root.cache)) }
        }
        const settle = () => {
            if (--job.left > 0) return
            if (job.best) finish()
            else if (live && root.key === k) { root.state = "none" }
        }
        const t0 = title.toLowerCase().replace(/\s*[\(\[].*$/, "")
        // 1: lrclib exact
        root.get("https://lrclib.net/api/get?track_name=" + encodeURIComponent(title) + "&artist_name=" + encodeURIComponent(a1) + (secs > 0 ? "&duration=" + Math.round(secs) : ""), (s, j) => {
            if (s === 200 && j?.syncedLyrics) offer(3, root.parseLrc(j.syncedLyrics), true, "lrclib")
            else if (s === 200 && j?.plainLyrics) offer(1, root.parsePlain(j.plainLyrics), false, "lrclib")
            settle()
        })
        // 2: lrclib search
        root.get("https://lrclib.net/api/search?q=" + encodeURIComponent(a1 + " " + title), (s, j) => {
            const hit = Array.isArray(j) ? (j.find(r => r.syncedLyrics && (secs <= 0 || Math.abs(r.duration - secs) < 6)) ?? j.find(r => r.syncedLyrics)) : null
            if (hit?.syncedLyrics) offer(2.5, root.parseLrc(hit.syncedLyrics), true, "lrclib")
            else if (Array.isArray(j) && j[0]?.plainLyrics) offer(1, root.parsePlain(j[0].plainLyrics), false, "lrclib")
            settle()
        })
        // 3: NetEase (timed lyrics for most big songs)
        root.get("https://music.163.com/api/search/get?type=1&limit=8&s=" + encodeURIComponent(a1 + " " + title), (s, j) => {
            const songs = j?.result?.songs ?? []
            const named = songs.filter(x => x.name.toLowerCase().startsWith(t0))
            const ok = named.filter(x => x.artists.some(a => a.name.toLowerCase().includes(a1.toLowerCase().slice(0, 5))))
            const best = ok.find(x => secs > 0 && Math.abs(x.duration / 1000 - secs) < 4) ?? ok[0] ?? named.find(x => secs > 0 && Math.abs(x.duration / 1000 - secs) < 3)
            if (!best) { settle(); return }
            root.get("https://music.163.com/api/song/lyric?lv=1&kv=1&tv=-1&id=" + best.id, (s2, j2) => {
                const raw = (j2?.lrc?.lyric ?? "").split("\n").filter(l => !/^\[0?0:0\d[^\]]*\]\s*(作词|作曲|编曲|制作|Lyrics|Composer|Producer)/i.test(l)).join("\n")
                const lines = root.parseLrc(raw)
                if (lines.length > 3) offer(2, lines, true, "NetEase")
                settle()
            })
        })
        // 4: lyrics.ovh (plain)
        root.get("https://api.lyrics.ovh/v1/" + encodeURIComponent(a1) + "/" + encodeURIComponent(title), (s, j) => {
            if (s === 200 && j?.lyrics) offer(0.5, root.parsePlain(j.lyrics), false, "lyrics.ovh")
            settle()
        })
        // do not wait forever for the slowest source: after 4 s use what there is
        Qt.callLater(() => {})
    }

    function request(title: string, artist: string, secs: real): void {
        if (title.length === 0) return
        const k = root.keyOf(title, artist)
        if (k === root.key && root.state !== "down") return
        root.key = k; root.lines = []; root.synced = false; root.secs = secs; root.estimated = false
        const c = root.cache[k]
        if (c) {
            root.set(k, c.lines, c.synced, false, c.source ?? "cache")
            // plain words in the cache: look once more for timed ones in the background
            if (!c.synced && !root.tried[k]) { root.tried[k] = true; root.run(k, title, artist, secs, true) }
            return
        }
        root.state = "loading"
        root.run(k, title, artist, secs, true)
    }
    // The song after this one, so its words are ready before it starts.
    function prefetch(title: string, artist: string, secs: real): void {
        if (title.length === 0) return
        const k = root.keyOf(title, artist)
        if (root.cache[k] || root.tried["p" + k]) return
        root.tried["p" + k] = true
        root.run(k, title, artist, secs, false)
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/echo/lyrics.json"
        onLoaded: { try { root.cache = JSON.parse(file.text()) } catch (e) {} }
    }
}
