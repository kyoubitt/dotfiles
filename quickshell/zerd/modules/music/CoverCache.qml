pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Covers on disk. The first time a picture is asked for it is fetched once and kept in ~/.cache/zerd-covers; from then
// on it opens from the file at once, also after a restart, instead of being downloaded again for every view.
// `src(url)` gives the file when it is there and the web address while it is on its way.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.cache/zerd-covers"
    property var have: ({})                  // key -> true once the file exists
    property int rev: 0                      // bumps when a download lands, so bindings ask again
    property var pending: ({})
    property var queue: []

    function keyOf(url: string): string {
        let h = 5381
        for (let i = 0; i < url.length; i++) h = ((h << 5) + h + url.charCodeAt(i)) | 0
        return (h >>> 0).toString(16)
    }
    function src(url: var): string {
        let u = String(url ?? "")
        void root.rev
        // Soloist names a picture as spotify:image:<id>; the web address is on Spotify's image host
        if (u.startsWith("spotify:image:")) u = "https://i.scdn.co/image/" + u.slice(14)
        if (u.length === 0 || !/^https?:\/\//.test(u)) return u
        const k = root.keyOf(u)
        if (root.have[k]) return "file://" + root.dir + "/" + k + ".jpg"
        if (!root.pending[k]) { root.pending[k] = true; root.queue.push({ k: k, u: u }); pump.restart() }
        return u
    }

    Process { running: true; command: ["sh", "-c", "mkdir -p \"" + root.dir + "\"; find \"" + root.dir + "\" -type f -mtime +21 -delete; for f in \"" + root.dir + "\"/*.jpg; do [ \"$(head -c4 \"$f\" 2>/dev/null)\" = RIFF ] && magick \"$f\" -quality 88 \"$f.tmp.jpg\" && mv \"$f.tmp.jpg\" \"$f\"; done; ls \"" + root.dir + "\""]
        stdout: StdioCollector { onStreamFinished: {
            const h = {}
            for (const f of text.split("\n")) if (f.endsWith(".jpg")) h[f.slice(0, -4)] = true
            root.have = h; root.rev++
        } } }

    property var current: null
    Timer { id: pump; interval: 40; onTriggered: root.next() }
    function next(): void {
        if (dl.running || root.queue.length === 0) return
        root.current = root.queue.shift()
        // Qt here has no WebP reader and Spotify serves some pictures as WebP: those are turned into JPEG on the way in
        dl.command = ["sh", "-c", "curl -sfL --max-time 15 -o \"$1.part\" \"$2\" || exit 1; if [ \"$(head -c4 \"$1.part\")\" = RIFF ]; then magick \"$1.part\" -resize '640x640>' -quality 88 \"$1\" && rm -f \"$1.part\"; else mv \"$1.part\" \"$1\"; fi", "_", root.dir + "/" + root.current.k + ".jpg", root.current.u]
        dl.running = true
    }
    Process {
        id: dl
        onExited: code => {
            const c = root.current
            if (c) {
                if (code === 0) { const h = root.have; h[c.k] = true; root.have = h; root.rev++ }
                delete root.pending[c.k]
            }
            root.current = null
            pump.restart()
        }
    }
}
