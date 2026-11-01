pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// The wallpaper list, the favourites and history, and the transition asked for by the picker.
// The list comes from scripts/colors/tag_wallpaper_colors.py (every image under ~/Pictures/Wallpapers with
// its colour bucket); applying goes through Wallpapers.apply (switchwall.sh: path, colours, everything else).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/zerd"
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/zerd/wallpaper-thumbs"
    readonly property string indexPath: Quickshell.env("HOME") + "/.cache/zerd/wallpaper-index.json"
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/zerd-wallpaper.json"
    readonly property var kinds: ["fade", "wipe-l", "wipe-r", "wipe-u", "wipe-d", "open", "circle", "blinds", "zoom"]
    readonly property string current: Config.options?.background?.wallpaperPath ?? ""

    property var items: []                 // [{ path, name, color }]
    property var thumbReady: ({})          // md5 of the path -> true, once the thumbnail exists

    // The picture to show for a wallpaper: its small thumbnail, or nothing until that exists.
    function thumbUrl(path: string): string {
        const h = Qt.md5(path)
        return root.thumbReady[h] ? "file://" + root.thumbDir + "/" + h + ".jpg" : ""
    }
    property bool loading: false
    property string sortMode: "colour"     // colour, name or newest
    readonly property var sortModes: ["colour", "name", "newest"]
    property string fixedKind: "random"    // random or one of `kinds`
    property var favourites: []
    property var history: []
    // Asked for by whoever applies the wallpaper, taken by the stage when the new picture arrives.
    property var request: null

    function take(): var { const r = root.request; root.request = null; return r }
    function pickKind(): string { return root.fixedKind !== "random" ? root.fixedKind : root.kinds[Math.floor(Math.random() * root.kinds.length)] }

    function apply(path: string, kind: string, ox: real, oy: real): void {
        if (!path || path === root.current) return
        root.request = { kind: kind && kind.length > 0 && root.fixedKind === "random" ? kind : root.pickKind(), x: ox, y: oy }
        Wallpapers.apply(path)
        root.history = [path].concat(root.history.filter(h => h !== path)).slice(0, 40)
        root.save()
    }
    function toggleFavourite(path: string): void {
        root.favourites = root.favourites.includes(path) ? root.favourites.filter(f => f !== path) : root.favourites.concat([path])
        root.save()
    }
    function setKind(k: string): void { root.fixedKind = k; root.save() }
    function cycleSort(): void { root.sortMode = root.sortModes[(root.sortModes.indexOf(root.sortMode) + 1) % root.sortModes.length]; root.save() }

    function refresh(): void {
        if (!thumbs.running) { thumbs.pending = {}; thumbs.running = true }
        if (indexer.running) return
        indexer.buffer = []
        root.loading = true
        indexer.running = true
    }

    // Thumbnails are made in the background (see scripts/wallpaper-thumbs.sh) and announced as they appear.
    Process {
        id: thumbs
        property var pending: ({})
        command: ["bash", Quickshell.shellPath("scripts/wallpaper-thumbs.sh"), root.dir, root.current]
        stdout: SplitParser { onRead: line => { const h = line.trim(); if (h.length === 32) { thumbs.pending[h] = true; flush.restart() } } }
        onExited: flush.restart()
    }
    Timer { id: flush; interval: 150; onTriggered: root.thumbReady = Object.assign({}, root.thumbReady, thumbs.pending) }

    Process {
        id: indexer
        property var buffer: []
        command: ["python3", Quickshell.shellPath("scripts/colors/tag_wallpaper_colors.py"), root.dir]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split("\t")
                if (p.length < 2) return
                const path = p[0]
                indexer.buffer.push({ path: path, name: path.split("/").pop().replace(/\.[^.]+$/, ""), color: p[1].trim(), light: parseInt(p[2] ?? "50"), mtime: parseInt(p[3] ?? "0") })
            }
        }
        onExited: {
            root.items = indexer.buffer
            root.loading = false
            indexFile.setText(JSON.stringify(indexer.buffer))
        }
    }

    // The list as it was last time, so the picker has every slice the moment it opens.
    FileView {
        id: indexFile
        path: root.indexPath
        onLoaded: { try { if (root.items.length === 0) root.items = JSON.parse(indexFile.text()) } catch (e) {} }
    }
    Component.onCompleted: Qt.callLater(root.refresh)

    function save(): void { file.setText(JSON.stringify({ favourites: root.favourites, history: root.history, kind: root.fixedKind, sort: root.sortMode })) }
    FileView {
        id: file
        path: root.stateFile
        onLoaded: {
            try {
                const d = JSON.parse(file.text())
                root.favourites = d.favourites ?? []
                root.history = d.history ?? []
                root.fixedKind = d.kind ?? "random"
                root.sortMode = d.sort ?? "colour"
            } catch (e) {}
        }
    }
}
