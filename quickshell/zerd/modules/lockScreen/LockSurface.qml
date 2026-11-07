pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

// One lock surface per monitor. Two views: a clock view (any key moves on)
// and a login view. Auth state lives in LockScreen (`lock`); this file is
// presentation only. Text positions are rounded to whole pixels so text
// stays sharp.
Item {
    id: root

    required property var lock

    property bool loginView: false

    readonly property string userName: SystemInfo.username
    readonly property color fg: SMColors.fg
    readonly property color accent: SMColors.accent

    // Lets LockScreen's watchdog know this surface actually came up.
    Component.onCompleted: { root.lock.surfaceShown = true; appearAnim.start() }

    // 0..1 when the surface comes up: the wallpaper, clock and avatar fade and rise in instead of popping.
    property real appear: 0
    NumberAnimation { id: appearAnim; target: root; property: "appear"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

    // What the password check is doing, as the shapes and the avatar ring show it.
    readonly property string authState: root.lock.unlocking ? "success"
        : root.lock.verifying ? "verifying"
        : root.lock.failed ? "fail" : "typing"
    // The length of the password handed to PAM: the field is cleared on submit, the shapes stay while it is checked
    // and for the burst or fall that follows.
    property int sentLength: 0
    readonly property int shownLength: root.authState === "typing" ? passwordInput.text.length : root.sentLength
    Timer {
        id: failClear
        interval: 950
        onTriggered: root.sentLength = 0
    }
    onAuthStateChanged: {
        if (authState === "fail") failClear.restart()
        else { failClear.stop(); if (authState === "typing") sentLength = 0 }
    }
    // 0..1 over the short success fade (LockScreen waits 260 ms before the lock drops)
    property real unlockT: 0
    NumberAnimation { id: unlockAnim; target: root; property: "unlockT"; from: 0; to: 1; duration: 250; easing.type: Easing.Linear }
    Connections {
        target: root.lock
        function onUnlockingChanged() { if (root.lock.unlocking) unlockAnim.restart(); else { unlockAnim.stop(); root.unlockT = 0 } }
    }

    // Caps lock, read from the keyboard LED (only while the login view is up).
    property bool capsLock: false
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | grep -q 1 && echo on || echo off"]
        stdout: SplitParser { onRead: data => root.capsLock = data.trim() === "on" }
    }
    Timer {
        interval: 400
        repeat: true
        running: root.loginView
        onTriggered: if (!capsProc.running) capsProc.running = true
    }

    // "still checking" after a second or so of waiting on PAM.
    property bool slowCheck: false
    Timer {
        id: slowTimer
        interval: 1200
        running: root.lock.verifying
        onTriggered: root.slowCheck = true
    }
    Connections {
        target: root.lock
        function onVerifyingChanged() { if (!root.lock.verifying) root.slowCheck = false }
    }

    // The unlock hint is only needed right after locking.
    property bool hintShown: true
    Timer {
        interval: 4000
        running: !root.loginView
        onTriggered: root.hintShown = false
    }

    // Back to the clock view after a while on the login view.
    Timer {
        id: idleTimer
        interval: 20000
        running: root.loginView && !root.lock.verifying
        onTriggered: root.showClock()
    }

    function showLogin() {
        if (loginView) return
        loginView = true
        passwordInput.forceActiveFocus()
    }
    function showClock() {
        passwordInput.text = ""
        loginView = false
        hintShown = true
        passwordInput.forceActiveFocus()
    }

    // A fresh lock always starts on the clock view.
    Connections {
        target: root.lock
        function onLockedChanged() { if (root.lock.locked) root.showClock() }
        function onRefocusRequested() { passwordInput.forceActiveFocus() }
    }

    // 0..1 while the login view comes in; drives a staggered entrance
    // (avatar, then name, then field) instead of one block fading together.
    property real loginProgress: loginView ? 1 : 0
    Behavior on loginProgress { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    function stage(from) { return Math.max(0, Math.min(1, loginProgress * 3 - from)) }

    LockBackdrop {
        anchors.fill: parent
        opacity: root.appear
    }

    // Extra smoke over the wallpaper while logging in.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.loginView ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }

    // ---------------- clock view ----------------
    ColumnLayout {
        id: clockView
        property real slide: root.loginView ? -18 : 0
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2 - 10 + slide + (1 - root.appear) * 28)
        spacing: 6
        opacity: (root.loginView ? 0 : 1) * root.appear
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // Caelestia's clock, side by side, but every digit solid in the text colour with a soft shadow so it reads on any wallpaper
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            LockText {
                text: Qt.locale().toString(DateTime.clock.date, "hh")
                color: "#ffffff"
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
                font.pixelSize: 150
                font.weight: Font.DemiBold
                font.letterSpacing: -2
            }
            LockText {
                text: Qt.locale().toString(DateTime.clock.date, "mm")
                color: "#ffffff"
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
                font.pixelSize: 150
                font.weight: Font.DemiBold
                font.letterSpacing: -2
            }
        }
        LockText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale().toString(DateTime.clock.date, "dddd • d MMM").toUpperCase()
            color: "#ffffff"
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.45)
            font.pixelSize: 20
            font.weight: Font.DemiBold
            font.letterSpacing: 3
        }

        Item { Layout.preferredHeight: 22 }

        LockVisualizer {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: NowPlaying.isPlaying ? implicitHeight : 0
            points: root.lock.visualizerPoints
            opacity: NowPlaying.isPlaying ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        LockNotifications {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.topMargin: 6
        }
    }

    LockText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        text: "press any key to unlock"
        font.pixelSize: 13
        font.letterSpacing: 1
        opacity: root.loginView || !root.hintShown ? 0 : 0.6
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }

    // ---------------- login view ----------------
    ColumnLayout {
        id: loginCol
        property real slide: root.loginView ? 0 : 24
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2 + slide)
        spacing: 14
        // while unlocking the parts fade one after another (the pill and name first, the avatar last), so the
        // column itself only fades out at the very end
        opacity: root.loginView ? 1 - Math.max(0, Math.min(1, (root.unlockT - 0.75) / 0.25)) : 0
        visible: opacity > 0
        Behavior on opacity { enabled: !root.lock.unlocking; NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        LockAvatar {
            Layout.alignment: Qt.AlignHCenter
            size: 104
            state: root.authState
            opacity: root.stage(0) * (1 - Math.max(0, Math.min(1, (root.unlockT - 0.55) / 0.35)))
            transform: Translate { y: (1 - root.stage(0)) * 14 }
        }
        LockText {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            font.pixelSize: 22
            font.weight: Font.Medium
            font.letterSpacing: 0.5
            opacity: root.stage(0.4) * (1 - Math.max(0, Math.min(1, root.unlockT * 3)))
            transform: Translate { y: (1 - root.stage(0.4)) * 14 }
        }

        Item {
            id: fieldWrap
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            implicitWidth: 340
            implicitHeight: 54

            property real shakeOffset: 0
            property bool showPassword: false
            transform: [
                Translate { x: fieldWrap.shakeOffset },
                Translate { y: (1 - root.stage(0.8)) * 14 }
            ]
            opacity: root.stage(0.8)
            // the pill, lock glyph and button fade early on success; the shapes burst on their own
            property real chrome: 1 - Math.max(0, Math.min(1, root.unlockT * 3))

            Connections {
                target: root.lock
                function onShakeRequested() { shakeAnim.start() }
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: fieldWrap; property: "shakeOffset"; to: -12; duration: 40 }
                NumberAnimation { target: fieldWrap; property: "shakeOffset"; to: 12; duration: 80 }
                NumberAnimation { target: fieldWrap; property: "shakeOffset"; to: -6; duration: 60 }
                NumberAnimation { target: fieldWrap; property: "shakeOffset"; to: 0; duration: 40 }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                opacity: fieldWrap.chrome
                color: ColorUtils.applyAlpha("#000000", 0.5)
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: root.lock.failed ? Appearance.colors.colError
                            : root.lock.verifying || root.lock.unlocking ? ColorUtils.applyAlpha(root.accent, 0.5)
                            : ColorUtils.applyAlpha(root.accent, passwordInput.activeFocus ? 0.8 : 0.4)
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            // Status glyph: lock, turning into a warning after a bad password.
            LockIcon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 20
                text: root.capsLock ? "keyboard_capslock" : root.lock.failed ? "error" : "lock"
                fill: 1
                iconSize: 18
                color: root.lock.failed ? Appearance.colors.colError : root.fg
                opacity: (root.lock.failed || root.capsLock ? 1 : 0.65) * fieldWrap.chrome
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 52
                anchors.rightMargin: 96
                verticalAlignment: TextInput.AlignVCenter
                echoMode: fieldWrap.showPassword ? TextInput.Normal : TextInput.Password
                color: fieldWrap.showPassword ? root.fg : "transparent"
                selectionColor: root.accent
                font.family: Appearance.font.family.expressive
                font.pixelSize: 16
                renderType: Text.NativeRendering
                clip: true
                focus: true
                // typing is paused while PAM checks; the field keeps focus so keys are swallowed, not lost to the clock view
                readOnly: root.lock.verifying || root.lock.unlocking

                Component.onCompleted: forceActiveFocus()

                // Typing on the clock view moves to login; the keystroke is
                // already in the field, so nothing is lost.
                onTextChanged: {
                    idleTimer.restart()
                    if (text.length > 0) {
                        root.lock.failed = false
                        root.showLogin()
                    }
                }
                Keys.onEscapePressed: root.showClock()
                onAccepted: {
                    if (!root.loginView) { root.showLogin(); return }
                    if (root.lock.pseudoLock) { root.lock.submitPassword(text); return }
                    if (text.length > 0) {
                        const n = text.length
                        root.lock.submitPassword(text)
                        // only once PAM has taken it: otherwise the text stays so Enter can be pressed again
                        if (root.lock.verifying) {
                            root.sentLength = n
                            fieldWrap.showPassword = false
                            text = ""
                        }
                    }
                }

                LockText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: opacity > 0
                    text: "enter password"
                    opacity: root.shownLength === 0 ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    font.pixelSize: 16
                }
            }

            // outside the TextInput (which clips): tall, so the shapes can fall past the pill
            PasswordChars {
                x: 52
                y: (fieldWrap.height - height) / 2
                width: fieldWrap.width - 52 - 96
                height: 180
                state: root.authState
                visible: !fieldWrap.showPassword && root.shownLength > 0
                length: root.shownLength
            }

            LockIcon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: submitBtn.left
                anchors.rightMargin: 8
                visible: passwordInput.text.length > 0 && !root.lock.verifying
                text: fieldWrap.showPassword ? "visibility_off" : "visibility"
                iconSize: 18
                color: root.fg
                opacity: 0.6
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fieldWrap.showPassword = !fieldWrap.showPassword
                }
            }

            Rectangle {
                id: submitBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 9
                width: 36
                height: 36
                radius: width / 2
                color: root.accent
                opacity: (root.lock.verifying ? 0.45 : (passwordInput.text.length > 0 || root.lock.pseudoLock ? 1 : 0.45)) * fieldWrap.chrome
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Arrow; a check once the password is accepted. The ring and the shapes show the checking.
                LockIcon {
                    id: spinner
                    anchors.centerIn: parent
                    text: root.lock.unlocking ? "check" : "arrow_forward"
                    iconSize: 20
                    color: SMColors.bg
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passwordInput.accepted()
                }
            }
        }

        // One line of feedback under the field: each message fades in on its own ("wrong password" rises a little).
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 18
            opacity: 1 - Math.max(0, Math.min(1, root.unlockT * 3))

            LockText {
                anchors.centerIn: parent
                text: root.capsLock ? "caps lock is on" : "esc to go back"
                opacity: root.lock.failed || root.lock.verifying ? 0 : (root.capsLock ? 0.9 : 0.45)
                Behavior on opacity { NumberAnimation { duration: 200 } }
                font.pixelSize: 13
                font.letterSpacing: 0.3
            }
            LockText {
                anchors.centerIn: parent
                text: root.slowCheck ? "still checking…" : "checking…"
                opacity: root.lock.verifying ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                font.pixelSize: 13
                font.letterSpacing: 0.3
            }
            LockText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 + (root.lock.failed ? 0 : 6)
                text: root.lock.failCount >= 3 ? `wrong password · ${root.lock.failCount} attempts` : "wrong password"
                color: Appearance.colors.colError
                opacity: root.lock.failed ? 0.95 : 0
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                font.pixelSize: 13
                font.letterSpacing: 0.3
            }
        }
    }
}
