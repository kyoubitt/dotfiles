pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Native ext-session-lock-v1 lock screen. This IS a real security surface
// (WlSessionLock + PamContext against the "login" PAM service) - not a
// decorative overlay. Per Quickshell's own docs: if this component is
// destroyed or the shell exits while `locked`
// is true, the compositor leaves the screen permanently blanked until a
// fresh client connects - so this must stay a plain, always-instantiated
// child of the shell root, never behind a LazyLoader/conditional that could
// tear it down mid-lock.
Scope {
    id: root

    property bool locked: false
    property int failCount: 0
    // Visual-only preview lock: skips PAM entirely, dismissed by any Enter
    // press or the closePseudoLock IPC call - never wired to real auth, so
    // it can't be used as a bypass for an actual lock.
    property bool pseudoLock: false


    // --- Cava equalizer, one shared process regardless of monitor count ---
    property list<real> visualizerPoints: []
    Process {
        id: cavaProc
        running: root.locked && NowPlaying.isPlaying
        onRunningChanged: { if (!running) root.visualizerPoints = [] }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/lockscreen_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }

    // --- PAM auth: uses the "login" service (owned by util-linux, not
    // gtklock) so this keeps working regardless of gtklock being installed. ---
    property bool authBusy: false
    // True from the moment a password is handed to PAM until it answers;
    // drives the progress bar. `failed` colours the field after a bad try.
    property bool verifying: false
    property bool failed: false
    // Set by LockSurface when it comes up. If a lock is requested and no
    // surface appears, the watchdog below releases the lock rather than leave
    // the screen blank with nothing to type a password into.
    property bool surfaceShown: false
    readonly property bool canType: pam.active || pam.responseRequired
    // A password typed while PAM was still busy (answering the last attempt
    // or restarting) is held here and sent as soon as PAM asks for it.
    property string pendingPassword: ""
    // True for the short fade-out after a correct password, before the lock drops.
    property bool unlocking: false
    property double _submitAt: 0

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            console.log(`[LockScreen] pam message="${pam.message}" error=${pam.messageIsError} responseRequired=${pam.responseRequired} responseVisible=${pam.responseVisible}`)
        }

        onResponseRequiredChanged: {
            if (pam.responseRequired && root.pendingPassword.length > 0) {
                const queued = root.pendingPassword
                root.pendingPassword = ""
                root.verifying = true
                root._submitAt = Date.now()
                console.log("[LockScreen] sending queued password")
                pam.respond(queued)
            }
        }

        onCompleted: result => {
            root.authBusy = false
            console.log(`[LockScreen] pam completed in ${Date.now() - root._submitAt}ms: ${PamResult.toString(result)}`)
            if (result === PamResult.Success) {
                root.verifying = false
                root.pendingPassword = ""
                root.failCount = 0
                // Short fade-out, then drop the lock.
                root.unlocking = true
                unlockTimer.start()
            } else {
                root.failCount += 1
                const queued = root.pendingPassword.length > 0
                root.verifying = queued
                root.failed = !queued
                if (!queued) shakeRequested()
                retryTimer.start()
            }
        }

        onError: error => {
            root.authBusy = false
            root.verifying = false
            console.log(`[LockScreen] pam error: ${PamError.toString(error)}`)
            retryTimer.start()
        }
    }

    signal shakeRequested()

    Timer {
        interval: 2500
        running: root.locked && !root.surfaceShown
        onTriggered: {
            console.warn("[LockScreen] no lock surface appeared, releasing the lock")
            root.locked = false
            Quickshell.execDetached(["/usr/bin/notify-send", "-u", "critical", "Lock screen failed to load", "Unlocked for safety."])
        }
    }
    signal refocusRequested()

    // niri can drop keyboard focus from the lock surface after resume; poke
    // the password field back into focus while locked.
    Timer {
        interval: 2000
        repeat: true
        running: root.locked
        onTriggered: root.refocusRequested()
    }

    Timer {
        id: unlockTimer
        interval: 260
        onTriggered: root.locked = false
    }

    Timer {
        id: retryTimer
        interval: 100
        onTriggered: {
            if (root.locked && !pam.active) {
                root.authBusy = true
                pam.start()
            }
        }
    }

    onLockedChanged: {
        GlobalStates.screenLocked = locked
        if (locked) {
            failCount = 0
            failed = false
            verifying = false
            unlocking = false
            pendingPassword = ""
            if (!pseudoLock) {
                authBusy = true
                pam.start()
            }
        } else {
            surfaceShown = false
            unlocking = false
            pendingPassword = ""
            unlockTimer.stop()
            if (pam.active) pam.abort()
            pseudoLock = false
        }
    }

    function submitPassword(text) {
        if (root.pseudoLock) {
            root.locked = false
            return
        }
        if (text.length === 0) return
        if (pam.responseRequired) {
            root.verifying = true
            root._submitAt = Date.now()
            pam.respond(text)
        } else if (pam.active || retryTimer.running || root.verifying) {
            // PAM is busy: hold the password and send it when it asks.
            root.pendingPassword = text
            root.verifying = true
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    // There is intentionally no unauthenticated `unlock` here: the only way
    // out of a real lock is the password box (or a TTY switch + qs kill as
    // a last resort). `closePseudoLock` only ever affects the fake preview
    // lock and is a no-op during a real one.
    IpcHandler {
        target: "lockScreen"
        function lock(): void { root.locked = true }
        function pseudoLock(): void { root.pseudoLock = true; root.locked = true }
        function closePseudoLock(): void { if (root.pseudoLock) root.locked = false }
        function status(): string { return root.locked ? (root.pseudoLock ? "pseudo-locked" : "locked") : "unlocked" }
    }
}
