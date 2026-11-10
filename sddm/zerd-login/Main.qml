// Material You login screen by Darkkal44 (MIT), taken from ilyamiro/serpantinum, config/sddm/themes/material-you.
// Colours and background here come from theme.conf (wallust), the bundled fonts and pictures are left out.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height

    component Ico: Item {
        id: ico
        property string name: "power"
        property color tint: root.cDark
        property real size: 20
        width: size
        height: size
        Image {
            id: icoImg
            anchors.fill: parent
            source: root.iconSource(ico.name)
            sourceSize.width: ico.size * 2
            sourceSize.height: ico.size * 2
            visible: false
        }
        MultiEffect {
            anchors.fill: icoImg
            source: icoImg
            brightness: 1.0
            colorization: 1.0
            colorizationColor: ico.tint
        }
    }

    component MenuContent: Item {
        id: bRoot
        property string iconName: "power"
        property string label: ""
        property color contentColor: root.cMid
        property real currentFill: 0.0

        Row {
            id: contentRow
            x: Math.round((bRoot.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.s

            Ico {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                name: bRoot.iconName
                tint: bRoot.contentColor
                size: 18 * root.s
                readonly property real norm: bRoot.width > 0 ? (contentRow.x + x + width / 2) / bRoot.width : 0
                readonly property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999 ? Math.exp(-Math.pow((bRoot.currentFill - norm) * 9, 2)) : 0.0
                transform: [
                    Translate { y: -icon.bump * root.s },
                    Scale {
                        origin.x: icon.width / 2
                        origin.y: icon.height / 2
                        xScale: 1.0 + icon.bump * 0.03
                        yScale: 1.0 + icon.bump * 0.03
                    }
                ]
            }

            Row {
                id: charRow
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: Array.from(bRoot.label)

                    Item {
                        id: slot
                        required property string modelData
                        required property int index
                        width: ct.implicitWidth
                        height: ct.implicitHeight
                        readonly property real norm: bRoot.width > 0 ? (contentRow.x + charRow.x + x + width / 2) / bRoot.width : 0
                        readonly property real bump: bRoot.currentFill > 0.001 && bRoot.currentFill < 0.999 ? Math.exp(-Math.pow((bRoot.currentFill - norm) * 9, 2)) : 0.0

                        Text {

                            renderType: Text.NativeRendering
                            id: ct
                            anchors.centerIn: parent
                            text: slot.modelData === " " ? "\u00A0" : slot.modelData
                            font.family: root.sansFont
                            font.pixelSize: 14 * root.s
                            font.weight: Font.Bold
                            color: bRoot.contentColor
                        }

                        transform: [
                            Translate { y: -slot.bump * 3.5 * root.s },
                            Scale {
                                origin.x: slot.width / 2
                                origin.y: slot.height / 2
                                xScale: 1.0 + slot.bump * 0.12
                                yScale: 1.0 + slot.bump * 0.12
                            },
                            Rotation {
                                origin.x: slot.width / 2
                                origin.y: slot.height / 2
                                angle: slot.bump * (slot.index % 2 === 0 ? -7 : 7)
                            }
                        ]
                    }
                }
            }
        }
    }

    component MenuButton: Item {
        id: btn
        property string iconName: "power"
        property string label: ""
        property color accent: root.cMid
        property int fillDuration: 800
        property real fillLevel: 0.0
        property bool isTriggered: false
        property real flashOpacity: 0.0
        property real popScale: 1.0
        readonly property bool hot: ma.containsMouse && !isTriggered
        signal triggered()

        height: 48 * root.s

        Timer {
            id: resetTimer
            interval: 1200
            onTriggered: {
                btn.isTriggered = false;
                fillAnim.stop();
                drainAnim.start();
            }
        }

        Rectangle {
            id: shape
            anchors.fill: parent
            radius: root.radius
            clip: true
            color: btn.hot ? root.cSurfaceHover : root.cSurfaceSolid
            scale: (ma.pressed && !btn.isTriggered ? 0.96 : (btn.hot ? 1.02 : 1.0)) * btn.popScale
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: btn; property: "popScale"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: btn; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
            }

            ShaderEffect {
                id: wave
                anchors.fill: parent
                property real radius: root.radius
                property real fillLevel: btn.fillLevel
                property real waveAmp: btn.fillLevel < 0.99 ? Math.min(10 * root.s, Math.min(width * btn.fillLevel, width - width * btn.fillLevel)) * Math.sin(btn.fillLevel * Math.PI) : 0
                property vector2d itemSize: Qt.vector2d(width, height)
                property real phase: 0.0
                property real vertical: 0.0
                property color color1: Qt.darker(btn.accent, 1.15)
                property color color2: btn.accent
                property vector4d params: Qt.vector4d(1.0, 0.0, 0.0, 0.0)
                visible: btn.fillLevel > 0.001
                fragmentShader: Qt.resolvedUrl("shaders/fluid_wave.frag.qsb")

                NumberAnimation on phase {
                    running: btn.fillLevel > 0.0 && btn.fillLevel < 1.0
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 800
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "#ffffff"
                opacity: btn.flashOpacity
                PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
            }

            MenuContent {
                width: shape.width
                height: shape.height
                iconName: btn.iconName
                label: btn.label
                contentColor: btn.hot ? root.cText : btn.accent
                currentFill: btn.fillLevel
            }

            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                readonly property real maxAmp: Math.min(10 * root.s, Math.min(parent.width * btn.fillLevel, parent.width * (1.0 - btn.fillLevel)))
                readonly property real waveAmp: maxAmp * Math.sin(btn.fillLevel * Math.PI)
                readonly property real phaseOffset: Math.sin(wave.phase) - Math.cos(wave.phase)
                readonly property real centerOffset: btn.fillLevel > 0.01 && btn.fillLevel < 0.99 ? 0.375 * waveAmp * phaseOffset : 0
                width: Math.max(0, Math.min(parent.width, parent.width * btn.fillLevel + centerOffset))
                clip: true

                MenuContent {
                    width: shape.width
                    height: shape.height
                    iconName: btn.iconName
                    label: btn.label
                    contentColor: root.cOnAccent
                    currentFill: btn.fillLevel
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                enabled: !btn.isTriggered
                cursorShape: btn.isTriggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                onPressed: {
                    drainAnim.stop();
                    fillAnim.start();
                }
                onReleased: {
                    if (!btn.isTriggered && btn.fillLevel < 1.0) {
                        fillAnim.stop();
                        drainAnim.start();
                    }
                }
                onCanceled: {
                    if (!btn.isTriggered && btn.fillLevel < 1.0) {
                        fillAnim.stop();
                        drainAnim.start();
                    }
                }
            }
        }

        NumberAnimation {
            id: fillAnim
            target: btn
            property: "fillLevel"
            to: 1.0
            duration: btn.fillDuration * (1.0 - btn.fillLevel)
            easing.type: Easing.InSine
            onFinished: {
                btn.isTriggered = true;
                btn.flashOpacity = 0.5;
                popAnim.start();
                flashAnim.start();
                btn.triggered();
                resetTimer.restart();
            }
        }

        NumberAnimation {
            id: drainAnim
            target: btn
            property: "fillLevel"
            to: 0.0
            duration: btn.fillDuration * 1.875 * btn.fillLevel
            easing.type: Easing.OutQuad
        }
    }

    readonly property real s: Screen.height / 768
    readonly property real radius: 16 * s
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0

    // Night light: automatic. From 19:00 to 07:00 a warm, slightly dimmed, blue-free tint lies over the whole greeter; it fades in or
    // out by itself when the hour changes while the screen is open. There is no switch for it.
    property int hourNow: cfg("TestHour", "") !== "" ? Number(cfg("TestHour", "")) : new Date().getHours()
    Timer { interval: 30000; repeat: true; running: cfg("TestHour", "") === ""; onTriggered: root.hourNow = new Date().getHours() }
    readonly property bool night: hourNow >= 19 || hourNow < 7

    // palette from theme.conf: scripts/theme-sync.sh rewrites it from wallust on every wallpaper change
    function cfg(name, fallback) { return (typeof config !== "undefined" && config[name]) ? config[name] : fallback }
    readonly property color cText: cfg("TimeTextColor", "#EEE3FD")
    readonly property color cDark: cfg("LoginButtonBackgroundColor", "#CBA6F7")
    readonly property color cMid: Qt.darker(cDark, 1.15)
    readonly property color cSurface: Qt.rgba(cSolid.r, cSolid.g, cSolid.b, 0.9)
    readonly property color cSolid: cfg("FormBackgroundColor", "#241636")
    readonly property color cField: cfg("LoginFieldBackgroundColor", "#33214F")
    readonly property color cSurfaceHover: Qt.lighter(cField, 1.2)
    readonly property color cFieldBox: Qt.lighter(cField, 1.45)
    readonly property color cSurfaceSolid: cSolid
    readonly property color cOnAccent: cfg("LoginButtonTextColor", "#1E1233")
    readonly property color cRed: "#ff6b7a"
    readonly property color cBusy: cDark
    readonly property color cMenu1: cMid
    readonly property color cMenu2: cDark
    readonly property color cMenuDanger: "#ff6b7a"

    property real ui1: 0
    property bool powerMenuOpen: false
    property var now: new Date()

    readonly property string sansFont: cfg("Font", "Inter, Roboto, sans-serif")
    readonly property string flexName: sansFont

    readonly property var icons: ({
        "power": "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/>",
        "close": "<line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/>",
        "session": "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'/>",
        "reboot": "<polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/>",
        "user": "<path d='M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>",
        "moon": "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>",
        "sun": "<circle cx='12' cy='12' r='4'/><line x1='12' y1='2' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='22'/><line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/><line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/><line x1='2' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='22' y2='12'/><line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/><line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/>",
        "sleep": "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>"
    })

    function iconSource(name) {
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'>" + icons[name] + "</svg>";
    }

    function sessionName() {
        return (sessionHelper.currentItem && sessionHelper.currentItem.sName) ? sessionHelper.currentItem.sName : "Plasma";
    }

    function userName() {
        return (userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : (userModel.lastUser || "User");
    }

    // your account picture, round, between the date and the password field
    readonly property string avatarSource: cfg("AvatarPath", "") !== "" ? "file://" + cfg("AvatarPath", "") : ((userHelper.currentItem && userHelper.currentItem.uIcon) ? userHelper.currentItem.uIcon : "")
    Item {
        id: avatar
        z: 5
        width: 72 * s; height: width
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height * 0.555 - height / 2)
        visible: avatarImg.status === Image.Ready
        opacity: root.ui1
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 3 * s; border.color: root.cDark }
        Image {
            id: avatarImg
            x: 5 * s; y: 5 * s; width: parent.width - 10 * s; height: width
            source: root.avatarSource
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
            visible: false
        }
        Rectangle { id: avatarMask; x: 5 * s; y: 5 * s; width: parent.width - 10 * s; height: width; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { x: 5 * s; y: 5 * s; width: parent.width - 10 * s; height: width; source: avatarImg; maskEnabled: true; maskSource: avatarMask }
    }

    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string sName: model.name || ""
        }
    }

    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string uName: model.realName || model.name || ""
            property string uLogin: model.name || ""
            property string uIcon: model.icon || ""
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: focusTimer
        interval: 300
        running: true
        onTriggered: pw.forceInputFocus()
    }

    Timer {
        id: busyGuard
        interval: 15000
        onTriggered: pw.isBusy = false
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            busyGuard.stop();
            pw.isBusy = false;
            pw.clear();
            pw.markError();
            errTimer.restart();
        }
    }

    Timer {
        id: errTimer
        interval: 3000
        onTriggered: pw.resetVerification()
    }

    Component.onCompleted: {
        fadeAnim.start();
        if (typeof keyboard !== "undefined") keyboard.numLock = true;
    }

    SequentialAnimation {
        id: fadeAnim
        PauseAnimation { duration: 300 }
        NumberAnimation { target: root; property: "ui1"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    }

    Item {
        id: scene
        anchors.fill: parent

    Image {
        id: wall
        anchors.fill: parent
        anchors.margins: -24 * s
        source: cfg("Background", "/var/cache/sddm-wallust/background.jpg")
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect { source: wall; anchors.fill: wall; blurEnabled: true; blur: 0.85; blurMax: 40; brightness: -0.04 }
    }

    // soft vignette: the edges settle, the middle stays clear
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.2) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.26) }
        }
        opacity: root.ui1
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.powerMenuOpen = false;
            pw.forceInputFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.powerMenuOpen
        onActivated: {
            root.powerMenuOpen = false;
            pw.forceInputFocus();
        }
    }

    Column {
        id: mainLayout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -15 * s
        spacing: 16 * s
        opacity: root.ui1
        scale: 0.96 + (0.04 * root.ui1)
        transform: Translate { y: (1 - root.ui1) * 30 * s }

        Rectangle {
            id: clockCard
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockRow.width
            height: clockRow.height
            color: "transparent"

            // the time as hh:mm in one row, solid digits with a soft shadow, the colon breathing once a second
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 4 * s
                readonly property real px: Math.round(112 * s)
                Repeater {
                    model: [{ t: Qt.formatTime(root.now, "hh"), colon: false }, { t: ":", colon: true }, { t: Qt.formatTime(root.now, "mm"), colon: false }]
                    delegate: Text {
                        required property var modelData
                        text: modelData.t
                        font.family: root.flexName
                        font.pixelSize: clockRow.px
                        font.weight: Font.Bold
                        font.letterSpacing: -1 * s
                        renderType: Text.NativeRendering
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.45)
                        color: root.cText
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: dateText.implicitWidth + 32 * s
            height: 32 * s
            radius: root.radius
            color: "transparent"

            Text {

                renderType: Text.NativeRendering
                id: dateText
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 2.5 * s
                anchors.centerIn: parent
                text: Qt.formatDate(root.now, "dddd, MMM d")
                font.family: root.sansFont
                font.pixelSize: 15 * s
                font.weight: Font.Medium
                color: root.cText
            }
        }

        Item {
            width: 1
            height: 94 * s
        }

        Item {
            id: pw
            anchors.horizontalCenter: parent.horizontalCenter
            width: 380 * s
            height: 40 * s

            property string text: ""
            property bool isRevealed: false
            property bool hasError: false
            property bool isBusy: false
            property real focusPop: 1.0
            property real scrollOffset: 0
            property real typePulse: 0
            readonly property bool hasFocus: innerInput.activeFocus
            readonly property real fontSize: 14 * s
            readonly property real dotSize: Math.round(height * 0.44)
            readonly property int charSpacing: Math.round(2 * s)
            readonly property real charSlotStep: (revealProgress > 0.5 ? charMetrics.width : dotSize) + charSpacing
            readonly property real btnSize: height - 8 * s
            readonly property real btnRadius: Math.max(4 * s, root.radius - 4 * s)
            property real revealProgress: isRevealed ? 1.0 : 0.0
            readonly property color signalColor: hasError ? root.cRed : (isBusy ? root.cBusy : root.cDark)

            Behavior on revealProgress {
                NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
            }

            function forceInputFocus() { innerInput.forceActiveFocus(); }
            function toggleReveal() { isRevealed = !isRevealed; submitBtn.triggerSpin(); }
            function resetVerification() { hasError = false; }
            function markError() {
                hasError = true;
                shakeAnim.restart();
            }

            function clear() {
                innerInput.text = "";
                text = "";
                charModel.clear();
                scrollOffset = 0;
            }

            function submit() {
                if (isBusy || innerInput.text === "") return;
                if (!root.isQuickshell) {
                    isBusy = true;
                    busyGuard.restart();
                    let currentUser = userHelper.currentItem ? userHelper.currentItem.uLogin : userModel.lastUser;
                    sddm.login(currentUser, innerInput.text, root.sessionIndex);
                }
            }

            function syncModel() {
                let str = innerInput.text;
                let minLen = Math.min(str.length, charModel.count);
                let matchLen = 0;
                while (matchLen < minLen && str[matchLen] === charModel.get(matchLen).glyph) matchLen++;
                while (charModel.count > matchLen) charModel.remove(charModel.count - 1);
                for (let i = matchLen; i < str.length; i++) charModel.append({ glyph: str[i] });
                updateScroll();
            }

            function updateScroll() {
                let totalW = charRow.contentWidth;
                let visibleW = fieldArea.width;
                if (visibleW <= 0) return;
                if (totalW <= visibleW) {
                    scrollOffset = (visibleW - totalW) / 2;
                    return;
                }
                let curX = innerInput.cursorPosition * charSlotStep;
                let minOffset = visibleW - totalW;
                let margin = 4;
                let curScreenX = curX + scrollOffset;
                if (curScreenX < margin) {
                    scrollOffset = Math.min(0, Math.max(minOffset, margin - curX));
                } else if (curScreenX > visibleW - margin - 2) {
                    scrollOffset = Math.min(0, Math.max(minOffset, visibleW - margin - 2 - curX));
                } else {
                    scrollOffset = Math.min(0, Math.max(minOffset, scrollOffset));
                }
            }

            onRevealProgressChanged: { updateScroll(); lockButton.canvas.requestPaint(); }
            onHasErrorChanged: lockButton.canvas.requestPaint()
            onIsBusyChanged: {
                if (!isBusy) lockButton.busyRotation = 0;
                lockButton.canvas.requestPaint();
            }
            onHasFocusChanged: {
                if (hasFocus) focusPopAnim.restart();
                lockButton.canvas.requestPaint();
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; from: 0; to: -6 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: -6 * s; to: 6 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: 6 * s; to: -4 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: -4 * s; to: 4 * s; duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; from: 4 * s; to: 0; duration: 50 }
            }

            SequentialAnimation {
                id: focusPopAnim
                NumberAnimation { target: pw; property: "focusPop"; to: 1.02; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: pw; property: "focusPop"; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
            }

            TextMetrics {
                id: charMetrics
                font.family: root.sansFont
                font.pixelSize: pw.fontSize + 2 * s
                text: "0"
            }

            ListModel { id: charModel }

            TapHandler {
                onTapped: pw.forceInputFocus()
            }

            Item {
                id: contentContainer
                anchors.fill: parent
                scale: (pw.hasError ? 1.02 : (pw.isBusy ? 0.98 : 1.0)) * pw.focusPop
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                transform: Translate { id: shakeT; x: 0 }

                Rectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: "transparent"
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    // no box: a thin line under the text instead
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2 * s; radius: height / 2; color: root.cText; opacity: 0.55 }
                }

                Item {
                    id: lockButton
                    x: 4 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: pw.btnSize
                    height: pw.btnSize
                    property real busyRotation: 0
                    property alias canvas: lockCanvas
                    readonly property color iconColor: pw.hasError ? root.cRed : (pw.isBusy ? root.cBusy : "#ffffff")
                    onIconColorChanged: lockCanvas.requestPaint()
                    onBusyRotationChanged: lockCanvas.requestPaint()

                    Rectangle {
                        anchors.fill: parent
                        radius: pw.btnRadius
                        color: lockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    SequentialAnimation {
                        running: pw.isBusy
                        loops: Animation.Infinite
                        NumberAnimation { target: lockButton; property: "busyRotation"; from: 0; to: 360; duration: 540; easing.type: Easing.InOutCubic }
                        PauseAnimation { duration: 480 }
                    }

                    Canvas {
                        id: lockCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            var w = width;
                            var h = height;
                            ctx.clearRect(0, 0, w, h);
                            var color = lockButton.iconColor;
                            var bodyW = Math.round(w * 0.52);
                            var bodyH = Math.round(bodyW * 0.76);
                            var stroke = Math.max(1.8, bodyW * 0.14);
                            var outerW = Math.round(bodyW * 0.62);
                            var rad = (outerW - stroke) / 2;
                            var shackleH = Math.round(rad + bodyH * 0.30);
                            var top = Math.round((h - (shackleH + bodyH)) / 2);
                            var bodyY = top + shackleH;
                            var topY = top + stroke / 2;
                            var cx = Math.round(w / 2);
                            var cy = Math.round(h / 2);
                            var bodyX = Math.round((w - bodyW) / 2);
                            var prog = pw.revealProgress;
                            var pivotX = cx - rad;
                            var pivotY = bodyY + stroke / 2;
                            var lift = Math.round(shackleH * 0.28 * prog);
                            var swing = -0.38 * prog;
                            var rightBottom = bodyY + 1.0 - Math.round(shackleH * 0.32 * prog);
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.rotate(lockButton.busyRotation * Math.PI / 180);
                            ctx.translate(-cx, -cy);
                            ctx.save();
                            ctx.strokeStyle = color;
                            ctx.lineWidth = stroke;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.translate(pivotX, pivotY);
                            ctx.translate(0, -lift);
                            ctx.rotate(swing);
                            ctx.translate(-pivotX, -pivotY);
                            ctx.beginPath();
                            ctx.arc(cx, topY + rad, rad, Math.PI, 0, false);
                            ctx.lineTo(cx + rad, rightBottom);
                            ctx.moveTo(cx - rad, topY + rad);
                            ctx.lineTo(cx - rad, bodyY + 1.5 + lift);
                            ctx.stroke();
                            ctx.restore();
                            ctx.fillStyle = color;
                            var r = Math.max(2, Math.round(bodyW * 0.16));
                            ctx.beginPath();
                            ctx.moveTo(bodyX + r, bodyY);
                            ctx.lineTo(bodyX + bodyW - r, bodyY);
                            ctx.arcTo(bodyX + bodyW, bodyY, bodyX + bodyW, bodyY + r, r);
                            ctx.lineTo(bodyX + bodyW, bodyY + bodyH - r);
                            ctx.arcTo(bodyX + bodyW, bodyY + bodyH, bodyX + bodyW - r, bodyY + bodyH, r);
                            ctx.lineTo(bodyX + r, bodyY + bodyH);
                            ctx.arcTo(bodyX, bodyY + bodyH, bodyX, bodyY + bodyH - r, r);
                            ctx.lineTo(bodyX, bodyY + r);
                            ctx.arcTo(bodyX, bodyY, bodyX + r, bodyY, r);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = root.cField;
                            var kr = Math.max(1.4, bodyH * 0.16);
                            var ky = bodyY + Math.round(bodyH * 0.42);
                            ctx.beginPath();
                            ctx.arc(cx, ky, kr, 0, Math.PI * 2);
                            ctx.fill();
                            var slotW = Math.max(1.4, kr * 0.85);
                            ctx.beginPath();
                            ctx.rect(cx - slotW / 2, ky, slotW, Math.round(bodyH * 0.28));
                            ctx.fill();
                            ctx.restore();
                        }
                    }

                    MouseArea {
                        id: lockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pw.forceInputFocus();
                            pw.toggleReveal();
                        }
                    }
                }

                Item {
                    id: submitBtn
                    x: parent.width - width - 4 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: pw.btnSize
                    height: pw.btnSize
                    property real popScale: 1.0
                    property real flashOpacity: 0.0
                    readonly property bool hot: submitMa.containsMouse && !pw.isBusy
                    readonly property color accent: pw.hasError ? root.cRed : (pw.isBusy ? root.cBusy : root.cDark)

                    function triggerSpin() {
                        submitPop.restart();
                        flashOpacity = 0.4;
                        flashAnim.restart();
                        chevronSpin.restart();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: pw.btnRadius
                        clip: true
                        color: pw.isBusy ? submitBtn.accent : (submitMa.pressed ? Qt.darker(submitBtn.accent, 1.12) : (submitBtn.hot ? Qt.lighter(submitBtn.accent, 1.12) : submitBtn.accent))
                        opacity: pw.isBusy ? 0.5 : 1.0
                        scale: (pw.isBusy ? 1.0 : (submitMa.pressed ? 1.08 : (submitBtn.hot ? 1.04 : 1.0))) * submitBtn.popScale
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                        SequentialAnimation {
                            id: submitPop
                            NumberAnimation { target: submitBtn; property: "popScale"; to: 1.1; duration: 110; easing.type: Easing.OutQuad }
                            NumberAnimation { target: submitBtn; property: "popScale"; to: 1.0; duration: 400; easing.type: Easing.OutQuint }
                        }

                        Item {
                            id: chevron
                            anchors.centerIn: parent
                            width: submitBtn.width * 0.38
                            height: width
                            rotation: 180
                            property real armT: Math.max(1.5, submitBtn.width * 0.048)
                            property real armL: Math.max(5, submitBtn.width * 0.19)

                            NumberAnimation {
                                id: chevronSpin
                                target: chevron
                                property: "rotation"
                                from: 180
                                to: 540
                                duration: 400
                                easing.type: Easing.OutCubic
                            }

                            Item {
                                x: (chevron.width - chevron.armL * 0.766) / 2
                                y: chevron.height / 2
                                width: 0
                                height: 0
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: chevron.armT
                                    height: width
                                    radius: width / 2
                                    color: root.cField
                                    antialiasing: true
                                }
                                Rectangle {
                                    y: -chevron.armT / 2
                                    width: chevron.armL
                                    height: chevron.armT
                                    radius: height / 2
                                    transformOrigin: Item.Left
                                    rotation: 40
                                    color: root.cField
                                    antialiasing: true
                                }
                                Rectangle {
                                    y: -chevron.armT / 2
                                    width: chevron.armL
                                    height: chevron.armT
                                    radius: height / 2
                                    transformOrigin: Item.Left
                                    rotation: -40
                                    color: root.cField
                                    antialiasing: true
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: pw.btnRadius
                            color: "#ffffff"
                            opacity: submitBtn.flashOpacity
                            PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 400; easing.type: Easing.OutExpo }
                        }

                        MouseArea {
                            id: submitMa
                            anchors.fill: parent
                            hoverEnabled: !pw.isBusy
                            enabled: !pw.isBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                submitBtn.triggerSpin();
                                pw.forceInputFocus();
                                pw.submit();
                            }
                        }
                    }
                }

                Item {
                    id: fieldArea
                    anchors.left: lockButton.right
                    anchors.leftMargin: 6 * s
                    anchors.right: submitBtn.left
                    anchors.rightMargin: 6 * s
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4 * s
                    anchors.bottomMargin: 4 * s
                    clip: true
                    onWidthChanged: pw.updateScroll()

                    Text {

                        renderType: Text.NativeRendering
                        text: pw.hasError ? "Wrong password" : "Enter password"
                        font.family: root.sansFont
                        font.pixelSize: pw.fontSize + 2 * s
                        color: pw.hasError ? root.cRed : root.cMid
                        opacity: pw.hasError ? 1.0 : ((innerInput.text.length === 0 && !pw.hasFocus && charModel.count === 0) ? 0.55 : 0.0)
                        x: (fieldArea.width - implicitWidth) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Rectangle {
                        readonly property int selMin: Math.min(innerInput.selectionStart, innerInput.selectionEnd)
                        readonly property int selMax: Math.max(innerInput.selectionStart, innerInput.selectionEnd)
                        anchors.verticalCenter: parent.verticalCenter
                        height: Math.min(parent.height - 6 * s, pw.fontSize * 1.6)
                        radius: 4 * s
                        color: pw.signalColor
                        opacity: selMax > selMin ? 0.28 : 0.0
                        x: pw.scrollOffset + selMin * pw.charSlotStep - 2
                        width: selMax > selMin ? ((selMax - selMin) * pw.charSlotStep - pw.charSpacing + 4) : 0
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                        Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    }

                    ListView {
                        id: charRow
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: pw.charSpacing
                        width: contentWidth
                        x: pw.scrollOffset
                        model: charModel
                        onContentWidthChanged: pw.updateScroll()
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "scale"; from: 0.60; to: 1.0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
                                NumberAnimation { property: "y"; from: 3.5; to: 0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                NumberAnimation { property: "rotation"; from: -9; to: 0; duration: 250; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutQuad }
                            }
                        }
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "scale"; to: 0.0; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "y"; to: 2; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "rotation"; to: 6; duration: 130; easing.type: Easing.InCubic }
                                NumberAnimation { property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
                            }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: charSlot
                            required property int index
                            required property string glyph
                            width: pw.revealProgress > 0.5 ? charMetrics.width : pw.dotSize
                            height: charRow.height
                            transformOrigin: Item.Center

                            Rectangle {
                                id: charShape
                                anchors.centerIn: parent
                                width: pw.dotSize
                                height: width
                                // the lock screen's little shapes, in turn: circle, soft square, diamond, flower-ish squircle
                                readonly property int kind: charSlot.index % 4
                                radius: Math.round(width * [0.5, 0.24, 0.16, 0.38][kind])
                                color: root.cText
                                antialiasing: true
                                property real baseRot: kind === 2 ? 45 : (kind === 3 ? 22 : 0)
                                property color tint: root.cDark
                                ColorAnimation on color { id: tintIn; from: charShape.tint; to: root.cText; duration: 420; easing.type: Easing.OutCubic }
                                property real dotPop: 1.0
                                opacity: 1.0 - pw.revealProgress
                                scale: (1.0 - pw.revealProgress) * dotPop
                                rotation: baseRot + pw.revealProgress * -12
                                visible: opacity > 0.01
                                Component.onCompleted: {
                                    dotPop = 0.82;
                                    dotPopAnim.restart();
                                }
                                SequentialAnimation {
                                    id: dotPopAnim
                                    NumberAnimation { target: charShape; property: "dotPop"; to: 1.11; duration: 110; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                    NumberAnimation { target: charShape; property: "dotPop"; to: 1.0; duration: 170; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {

                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: charSlot.glyph
                                color: root.cText
                                font.family: root.sansFont
                                font.pixelSize: pw.fontSize + 2 * s
                                opacity: pw.revealProgress
                                scale: 0.88 + 0.12 * pw.revealProgress
                                rotation: (1.0 - pw.revealProgress) * 12
                                visible: opacity > 0.01
                            }
                        }
                    }

                    Rectangle {
                        id: caretRect
                        width: 2
                        height: pw.fontSize * 1.3
                        color: pw.signalColor
                        visible: pw.hasFocus && (pw.isRevealed || pw.revealProgress > 0.01)
                        anchors.verticalCenter: parent.verticalCenter
                        x: pw.scrollOffset + innerInput.cursorPosition * pw.charSlotStep
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        SequentialAnimation on opacity {
                            running: caretRect.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 120; easing.type: Easing.InQuad }
                            PauseAnimation { duration: 380 }
                            NumberAnimation { to: 1; duration: 120; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 380 }
                        }
                    }

                    TextInput {
                        id: innerInput
                        anchors.fill: parent
                        focus: true
                        opacity: 0
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        selectByMouse: true
                        horizontalAlignment: TextInput.AlignHCenter
                        font.family: root.sansFont
                        font.pixelSize: pw.fontSize + 2 * s
                        enabled: !pw.isBusy
                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        onCursorPositionChanged: pw.updateScroll()
                        onSelectionStartChanged: pw.updateScroll()
                        onSelectionEndChanged: pw.updateScroll()
                        Keys.onPressed: function(event) {
                            if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) {
                                event.accepted = true;
                                return;
                            }
                            if (event.matches(StandardKey.Copy) || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C)) {
                                event.accepted = true;
                            }
                        }
                        onTextEdited: {
                            pw.hasError = false;
                            pw.text = text;
                            pw.syncModel();
                        }
                        onAccepted: pw.submit()
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8 * s

            Rectangle {
                id: userChip
                width: userRow.implicitWidth + 36 * s
                height: 36 * s
                radius: root.radius
                color: userMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (userMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                scale: userMa.pressed ? 0.96 : 1.0
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Row {
                    id: userRow
                    anchors.centerIn: parent
                    spacing: 8 * s
                    Ico {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "user"
                        tint: "#ffffff"
                        size: 16 * s
                    }
                    Text {
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.userName()
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font.family: root.sansFont
                        font.pixelSize: 14 * s
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: userMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isQuickshell && typeof userModel !== "undefined" && userModel.rowCount() > 0) {
                            root.userIndex = (root.userIndex + 1) % userModel.rowCount();
                        }
                        pw.forceInputFocus();
                    }
                }
            }

            Rectangle {
                id: sessionChip
                width: sessionRow.implicitWidth + 36 * s
                height: 36 * s
                radius: root.radius
                color: sessionMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (sessionMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                scale: sessionMa.pressed ? 0.96 : 1.0
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Row {
                    id: sessionRow
                    anchors.centerIn: parent
                    spacing: 8 * s
                    Ico {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "session"
                        tint: "#ffffff"
                        size: 16 * s
                    }
                    Text {
                        renderType: Text.NativeRendering
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.sessionName()
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.5)
                        font.family: root.sansFont
                        font.pixelSize: 14 * s
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: sessionMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.isQuickshell && typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0) {
                            root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount();
                        }
                        pw.forceInputFocus();
                    }
                }
            }
        }
    }

    Item {
        id: powerDock
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20 * s
        anchors.bottomMargin: 16 * s
        width: 280 * s
        height: 36 * s
        opacity: root.ui1

        Rectangle {
            id: menu
            anchors.right: parent.right
            anchors.bottom: toggle.top
            anchors.bottomMargin: 12 * s
            width: parent.width
            height: root.powerMenuOpen ? menuCol.implicitHeight + 24 * s : 0
            radius: root.radius
            clip: true
            visible: height > 0 || opacity > 0
            opacity: root.powerMenuOpen ? 1.0 : 0.0
            color: root.cSurface
            transformOrigin: Item.BottomRight
            scale: 0.92
            Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Column {
                id: menuCol
                x: 12 * s
                y: 12 * s
                width: parent.width - 24 * s
                spacing: 8 * s

                MenuButton {
                    width: parent.width
                    iconName: "sleep"
                    label: "Suspend"
                    accent: root.cMenu1
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.suspend();
                    }
                }
                MenuButton {
                    width: parent.width
                    iconName: "reboot"
                    label: "Reboot"
                    accent: root.cMenu2
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.reboot();
                    }
                }
                MenuButton {
                    width: parent.width
                    iconName: "power"
                    label: "Power off"
                    accent: root.cMenuDanger
                    onTriggered: {
                        root.powerMenuOpen = false;
                        if (!root.isQuickshell) sddm.powerOff();
                    }
                }
            }
        }

        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 36 * s
            height: 36 * s
            radius: root.radius
            color: toggleMa.pressed ? Qt.rgba(1, 1, 1, 0.16) : (root.powerMenuOpen || toggleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
            scale: toggleMa.pressed ? 0.96 : 1.0
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            Ico {
                anchors.centerIn: parent
                name: root.powerMenuOpen ? "close" : "power"
                tint: root.powerMenuOpen ? root.cText : root.cRed
                size: 16 * s
            }

            MouseArea {
                id: toggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.powerMenuOpen = !root.powerMenuOpen;
                    if (!root.powerMenuOpen) pw.forceInputFocus();
                }
            }
        }
    }

    // night light tint: warm wash plus a dim; flips under the reveal snapshot, eases when there is none
    Rectangle {
        anchors.fill: parent
        z: 90
        color: Qt.rgba(1.0, 0.52, 0.1, 1)
        opacity: root.night ? 0.14 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    Rectangle {
        anchors.fill: parent
        z: 91
        color: Qt.rgba(0.05, 0.02, 0, 1)
        opacity: root.night ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    }
}
