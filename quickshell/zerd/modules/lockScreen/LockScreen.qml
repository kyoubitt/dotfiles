pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
import qs.modules.waffle.startMenu

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
        running: root.locked && MprisController.isPlaying
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

    PamContext {
        id: pam
        config: "login"

        onPamMessage: {
            console.log(`[LockScreen] pam message="${pam.message}" error=${pam.messageIsError} responseRequired=${pam.responseRequired} responseVisible=${pam.responseVisible}`)
        }

        onCompleted: result => {
            root.authBusy = false
            if (result === PamResult.Success) {
                root.failCount = 0
                root.locked = false
            } else {
                console.log(`[LockScreen] pam completed with failure: ${PamResult.toString(result)}`)
                root.failCount += 1
                shakeRequested()
                retryTimer.start()
            }
        }

        onError: error => {
            root.authBusy = false
            console.log(`[LockScreen] pam error: ${PamError.toString(error)}`)
            retryTimer.start()
        }
    }

    signal shakeRequested()

    Timer {
        id: retryTimer
        interval: 500
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
            if (!pseudoLock) {
                authBusy = true
                pam.start()
            }
        } else {
            if (pam.active) pam.abort()
            pseudoLock = false
        }
    }

    function submitPassword(text) {
        if (root.pseudoLock) {
            root.locked = false
            return
        }
        if (pam.active && text.length > 0) pam.respond(text)
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: "transparent"

            // Wallpaper background, blurred via a cached GPU layer effect
            // (only paid for while actually locked) rather than the old
            // always-composited Qt5Compat FastBlur.
            Image {
                id: bgSource
                anchors.fill: parent
                source: Wallpapers.effectiveWallpaperUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
                cache: true

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    source: bgSource
                    anchors.fill: bgSource
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                }
            }
            Rectangle {
                anchors.fill: parent
                color: SMColors.bg
                opacity: 0.55
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 28
                width: 460

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "hh:mm")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 72
                        font.bold: true
                        color: SMColors.fg
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: SMColors.fg
                        opacity: 0.7
                    }
                }

                Item {
                    id: passwordBoxWrapper
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 48

                    property real shakeOffset: 0
                    transform: Translate { x: passwordBoxWrapper.shakeOffset }

                    Connections {
                        target: root
                        function onShakeRequested() { shakeAnim.start() }
                    }

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: passwordBoxWrapper; property: "shakeOffset"; to: -10; duration: 40 }
                        NumberAnimation { target: passwordBoxWrapper; property: "shakeOffset"; to: 10; duration: 80 }
                        NumberAnimation { target: passwordBoxWrapper; property: "shakeOffset"; to: 0; duration: 40 }
                    }

                RectangularGlow {
                    anchors.fill: passwordBox
                    glowRadius: 12
                    spread: 0.35
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.35)
                    cornerRadius: passwordBox.radius + glowRadius
                }

                Rectangle {
                    id: passwordBox
                    anchors.fill: parent
                    radius: 24
                    antialiasing: true
                    color: SMColors.bg
                    opacity: 0.55
                    border.width: 1.5
                    border.color: pam.messageIsError ? "#e06c75" : ColorUtils.applyAlpha(SMColors.accent, 0.4)

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    property bool showPassword: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 14
                        spacing: 8

                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: passwordBox.showPassword ? TextInput.Normal : TextInput.Password
                            // Masked, the real glyphs render fully transparent - the icon
                            // row below draws the visible per-character feedback instead.
                            color: passwordBox.showPassword ? SMColors.fg : "transparent"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            clip: true
                            enabled: root.pseudoLock || pam.active || pam.responseRequired

                            Component.onCompleted: passwordInput.forceActiveFocus()

                            onAccepted: {
                                if (root.pseudoLock) {
                                    root.submitPassword(text)
                                    return
                                }
                                if (pam.active && text.length > 0) {
                                    root.submitPassword(text)
                                    text = ""
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text.length === 0
                                text: pam.messageIsError ? "Wrong password" : "Enter Password"
                                color: SMColors.fg
                                opacity: 0.5
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            // Per-character mask: plain filled circle per typed character.
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                visible: !passwordBox.showPassword && passwordInput.text.length > 0

                                Repeater {
                                    model: passwordInput.text.length
                                    delegate: Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 7
                                        radius: width / 2
                                        antialiasing: true
                                        color: SMColors.fg
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            visible: passwordInput.text.length > 0
                            text: passwordBox.showPassword ? "visibility_off" : "visibility"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: SMColors.fg
                            opacity: 0.6

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: passwordBox.showPassword = !passwordBox.showPassword
                            }
                        }
                    }
                }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: MprisController.activePlayer !== null
                    implicitWidth: nowPlayingRow.implicitWidth + 24
                    implicitHeight: nowPlayingRow.implicitHeight + 14
                    radius: implicitHeight / 2
                    antialiasing: true
                    color: SMColors.bg
                    opacity: 0.5

                    RowLayout {
                        id: nowPlayingRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "music_note"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 14
                            color: SMColors.fg
                            opacity: 0.7
                        }
                        Text {
                            text: `${MprisController.activeTrack?.title ?? ""} - ${MprisController.activeTrack?.artist ?? ""}`
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: SMColors.fg
                            opacity: 0.7
                        }
                    }
                }
            }

            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40; rightMargin: 40; bottomMargin: 28 }
                spacing: 6
                visible: MprisController.isPlaying

                Repeater {
                    model: 64
                    delegate: Rectangle {
                        id: eqBar
                        required property int index
                        readonly property real level: root.visualizerPoints.length > 0
                            ? Math.max(0, Math.min(1, (root.visualizerPoints[Math.min(eqBar.index, root.visualizerPoints.length - 1)] ?? 0) / 1000))
                            : 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        implicitHeight: 4 + level * 90
                        radius: 4
                        antialiasing: true
                        color: eqBar.index % 2 === 0 ? SMColors.accent : SMColors.fg
                        opacity: 0.4 + level * 0.6

                        Behavior on implicitHeight { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 70 } }
                    }
                }
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
