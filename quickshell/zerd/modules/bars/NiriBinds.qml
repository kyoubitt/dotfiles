pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's keyboard shortcuts as the config has them, and a safe way to change one (scripts/niri-binds.py backs the
// file up, asks niri to validate it and rolls back if niri refuses).
Singleton {
    id: root

    property var list: []
    property string message: ""
    readonly property string script: Quickshell.shellPath("scripts/niri-binds.py")

    function reload(): void { if (!listProc.running) listProc.running = true }
    function rebind(oldKey: string, newKey: string): void {
        if (rebindProc.running || newKey.trim().length === 0) return
        rebindProc.command = ["python3", "-I", root.script, "rebind", oldKey, newKey.trim()]
        rebindProc.running = true
    }
    // A readable name for a shortcut: its own title, else what the command does.
    function nameOf(b: var): string {
        if (b.title) return b.title
        const a = b.action
        const m = a.match(/^spawn(?:-sh)?\s+"(.*)"$/)
        if (m) {
            const c = m[1].replace(/^qs -c zerd ipc call\s+/, "").replace(/.*\//, "").trim()
            return c.charAt(0).toUpperCase() + c.slice(1)
        }
        const t = a.replace(/-/g, " ")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }

    Process {
        id: listProc
        command: ["python3", "-I", root.script, "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.list = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: rebindProc
        stdout: StdioCollector { onStreamFinished: { root.message = text.trim() === "ok" ? "Changed" : text.trim(); root.reload() } }
    }
}
