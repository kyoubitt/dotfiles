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
    Component.onCompleted: root.lock.surfaceShown = true

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
        function onVerifyingChanged() { if (!root.lock.verifying) spinner.rotation = 0 }
    }

    // 0..1 while the login view comes in; drives a staggered entrance
    // (avatar, then name, then field) instead of one block fading together.
    property real loginProgress: loginView ? 1 : 0
    Behavior on loginProgress { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    function stage(from) { return Math.max(0, Math.min(1, loginProgress * 3 - from)) }

    LockBackdrop {
        anchors.fill: parent
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
        y: Math.round((root.height - height) / 2 - 10 + slide)
        spacing: 6
        opacity: root.loginView ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        LockText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale().toString(DateTime.clock.date, "hh:mm")
            font.pixelSize: 124
            font.weight: Font.Medium
            font.letterSpacing: -1
        }
        LockText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale().toString(DateTime.clock.date, "dddd, d MMMM")
            opacity: 0.75
            font.pixelSize: 20
            font.letterSpacing: 1
        }

        Item { Layout.preferredHeight: 22 }

        LockBlocks {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
        }

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
        opacity: root.loginView && !root.lock.unlocking ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.lock.unlocking ? 220 : 350; easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        LockAvatar {
            Layout.alignment: Qt.AlignHCenter
            size: 104
            opacity: root.stage(0)
            transform: Translate { y: (1 - root.stage(0)) * 14 }
        }
        LockText {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            font.pixelSize: 22
            font.weight: Font.Medium
            font.letterSpacing: 0.5
            opacity: root.stage(0.4)
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
            opacity: root.stage(0.8) * (root.lock.verifying ? 0.8 : 1)
            Behavior on opacity { NumberAnimation { duration: 150 } }

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
                color: ColorUtils.applyAlpha("#000000", 0.5)
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: root.lock.failed ? Appearance.colors.colError
                            : root.lock.verifying ? ColorUtils.applyAlpha(root.accent, 0.5)
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
                opacity: root.lock.failed || root.capsLock ? 1 : 0.65
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
                renderType: Text.QtRendering
                clip: true
                focus: true

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
                        root.lock.submitPassword(text)
                        text = ""
                    }
                }

                LockText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text.length === 0
                    text: "enter password"
                    opacity: 0.55
                    font.pixelSize: 16
                }

                PasswordChars {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 28
                    visible: !fieldWrap.showPassword && passwordInput.text.length > 0
                    length: passwordInput.text.length
                }
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
                opacity: passwordInput.text.length > 0 || root.lock.pseudoLock || root.lock.verifying ? 1 : 0.45
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Arrow, swapped for a spinner while PAM is checking.
                LockIcon {
                    id: spinner
                    anchors.centerIn: parent
                    text: root.lock.verifying ? "progress_activity" : "arrow_forward"
                    iconSize: 20
                    color: SMColors.bg
                    NumberAnimation on rotation {
                        running: root.lock.verifying
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: passwordInput.accepted()
                }
            }
        }

        // One line of feedback under the field.
        LockText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 18
            text: root.lock.failed
                ? (root.lock.failCount >= 3 ? `wrong password · ${root.lock.failCount} attempts` : "wrong password")
                : root.lock.verifying ? (root.slowCheck ? "still checking…" : "checking…")
                : root.capsLock ? "caps lock is on" : "esc to go back"
            color: root.lock.failed ? Appearance.colors.colError : root.fg
            opacity: root.lock.failed || root.lock.verifying || root.capsLock ? 0.9 : 0.45
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 0.3
        }
    }
}
