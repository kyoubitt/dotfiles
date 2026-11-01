import QtQuick
import qs
import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // Window captured at the moment of trigger (prevents race condition)
    property var targetWindow: null
    property bool dialogVisible: false

    // Startup grace period - ignore IPC calls for the first moments after QS starts
    // This prevents accidental window closes when QS restarts after a crash
    property bool _startupGrace: true
    Timer {
        id: startupGraceTimer
        interval: 600
        running: true
        onTriggered: root._startupGrace = false
    }

    // Debounce to prevent double-trigger
    property bool _busy: false
    Timer {
        id: debounce
        interval: 600
        onTriggered: root._busy = false
    }

    // Config state
    readonly property bool confirmEnabled: Config.options?.closeConfirm?.enabled ?? false

    // Fallback: get focused window directly from niri when activeWindow is stale
    Process {
        id: focusedWindowProc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: SplitParser {
            onRead: line => {
                if (!line?.trim()) return
                try {
                    const win = JSON.parse(line)
                    if (win?.id) root.processWindow(win)
                } catch (e) {}
            }
        }
    }

    // Worth asking about: games, terminals, editors, browsers and the like, or a window with unsaved work.
    function isImportant(win): bool {
        const id = String(win?.app_id ?? "").toLowerCase()
        const title = String(win?.title ?? "").trim()
        if (/^[*•●]/.test(title)) return true
        const apps = Config.options?.closeConfirm?.apps ?? []
        return apps.some(a => id.includes(String(a).toLowerCase()))
    }

    function processWindow(win): void {
        if (root.confirmEnabled && root.isImportant(win)) {
            root.targetWindow = win
            root.dialogVisible = true
        } else {
            root.closeWindowFast(win)
        }
    }

    IpcHandler {
        target: "closeConfirm"

        function trigger(): void {
            // Ignore during startup grace period (prevents accidental closes after crash/restart)
            if (root._startupGrace) {
                console.log("closeConfirm: ignoring trigger during startup grace period")
                return
            }
            if (root._busy) return
            root._busy = true
            debounce.restart()

            if (!root.confirmEnabled) {
                // No dialog needed, so there's no reason to go through
                // NiriService.activeWindow (a QML-side mirror of niri's
                // focus state, updated reactively off niri's event
                // stream) at all here - it can lag a beat behind a focus
                // change that just happened (e.g. this trigger firing
                // right after switching focus to the window being
                // closed), which silently closed nothing: this IPC call
                // still returns success either way, so close-window.sh
                // never falls back to its own niri call. Calling niri's
                // close-window action directly acts on niri's own live,
                // authoritative focus - not a copy of it - so it can't
                // race like this.
                Quickshell.execDetached(["niri", "msg", "action", "close-window"])
                return
            }

            // Confirm-dialog path still needs the actual window object to
            // show in the dialog, so it keeps using the cached/queried
            // window data.
            const win = NiriService.activeWindow
            if (win?.id) {
                root.processWindow(win)
            } else {
                focusedWindowProc.running = true
            }
        }

        function close(): void {
            root.dialogVisible = false
            root.targetWindow = null
        }
    }

    function closeWindowFast(win): void {
        if (!win?.id) return
        // Use niri msg directly - more reliable than socket IPC for some apps
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.id)])
    }

    function confirmClose(): void {
        if (targetWindow) {
            closeWindowFast(targetWindow)
        }
        dialogVisible = false
        targetWindow = null
    }

    // For an app that ignores the close request: end its process.
    function forceQuit(): void {
        const pid = targetWindow?.pid
        // One process can own several windows (ghostty runs as a single instance): killing it would end them all,
        // so with sibling windows only this one is closed.
        const siblings = (NiriService.windows ?? []).filter(w => w.pid === pid && w.id !== targetWindow?.id).length
        if (pid && siblings === 0) Quickshell.execDetached(["kill", "-9", String(pid)])
        else if (targetWindow) closeWindowFast(targetWindow)
        dialogVisible = false
        targetWindow = null
    }

    function cancel(): void {
        dialogVisible = false
        targetWindow = null
    }

    // Dialog UI
    Loader {
        active: root.dialogVisible

        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:closeConfirm"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    focus: true
                    sourceComponent: waffleContent
                    onLoaded: if (item) item.forceActiveFocus()

                    Component {
                        id: waffleContent
                        CloseConfirmCard {
                            targetWindow: root.targetWindow
                            onConfirm: root.confirmClose()
                            onCancel: root.cancel()
                            onForce: root.forceQuit()
                        }
                    }
                }
            }
        }
    }
}
