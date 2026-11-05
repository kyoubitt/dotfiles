import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.VirtualKeyboard

// The login screen, built from the same glass blocks as the lock screen: a big clock, one block with your picture,
// name and the password pill, a block for the session and one for sleep / restart / shut down.
// Colours come from theme.conf, which scripts/theme-sync.sh rewrites from wallust on every wallpaper change.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.BackgroundColor

    readonly property color accent: config.LoginButtonBackgroundColor
    readonly property color onAccent: config.LoginButtonTextColor
    readonly property string fam: config.Font || "sans-serif"
    readonly property string icons: "Material Symbols Rounded"
    property bool failed: false
    property bool busy: false
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string userName: ""
    property string realName: ""
    property string userIcon: ""
    property string sessionName: ""
    // the picture: a path given in theme.conf (used for previews) wins, else the account's own
    readonly property string picture: config.AvatarPath ? "file://" + config.AvatarPath : (userIcon.length > 0 ? userIcon : "")

    // the chosen user and session, read from the models through two one-pixel lists
    ListView {
        width: 1; height: 1; opacity: 0; interactive: false
        model: userModel; currentIndex: root.userIndex; orientation: ListView.Horizontal
        delegate: Item {
            width: 1; height: 1
            readonly property bool on: ListView.isCurrentItem
            function take() { if (on) { root.userName = model.name; root.realName = model.realName || model.name; root.userIcon = model.icon || "" } }
            onOnChanged: take()
            Component.onCompleted: take()
        }
    }
    ListView {
        width: 1; height: 1; opacity: 0; interactive: false
        model: sessionModel; currentIndex: root.sessionIndex; orientation: ListView.Horizontal
        delegate: Item {
            width: 1; height: 1
            readonly property bool on: ListView.isCurrentItem
            function take() { if (on) root.sessionName = model.name }
            onOnChanged: take()
            Component.onCompleted: take()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { root.failed = true; root.busy = false; shake.restart(); pw.text = ""; pw.forceActiveFocus() }
        function onLoginSucceeded() { root.busy = false }
    }
    function login(): void {
        if (pw.text.length === 0 || root.busy) return
        root.failed = false; root.busy = true
        sddm.login(root.userName, pw.text, root.sessionIndex)
    }

    // ---- backdrop
    Image { id: wall; anchors.fill: parent; source: config.Background; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
    MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.2; saturation: 0.1 }
    Rectangle { anchors.fill: parent; color: config.DimBackgroundColor; opacity: 0.25 }

    // a glass block, the same everywhere
    component Glass: Rectangle {
        color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        antialiasing: true
    }
    component Round: Rectangle {
        id: rb
        property string icon
        property string tip
        signal clicked()
        width: 56; height: 56; radius: hov.containsMouse ? 20 : 28
        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        color: hov.containsMouse ? root.accent : Qt.rgba(1, 1, 1, 0.1)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 160 } }
        scale: hov.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text { anchors.centerIn: parent; text: rb.icon; font.family: root.icons; font.pixelSize: 26; color: hov.containsMouse ? root.onAccent : "#ffffff" }
        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
        ToolTip.visible: hov.containsMouse && tip.length > 0
        ToolTip.text: tip
    }

    // ---- clock
    Column {
        id: stack
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -70
        spacing: 0
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), config.HourFormat)
            font.family: root.fam; font.pixelSize: 140; font.weight: Font.Light
            renderType: Text.QtRendering
            color: "#ffffff"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), config.DateFormat)
            font.family: root.fam; font.pixelSize: 22
            renderType: Text.QtRendering
            color: root.accent
        }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatTime(new Date(), config.HourFormat) }
      }
      Item { width: 1; height: 72 }

    // ---- login block
      Item {
        id: card
        width: 440; height: 232
        anchors.horizontalCenter: parent.horizontalCenter

        Item {
            id: avatar
            width: 104; height: 104
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
                        Rectangle { id: fallback; x: 6; y: 6; width: 92; height: 92; radius: 46; color: root.accent
                Text { anchors.centerIn: parent; text: root.realName.length > 0 ? root.realName.charAt(0).toUpperCase() : "?"
                    font.family: root.fam; font.pixelSize: 40; font.weight: Font.Medium; color: root.onAccent } }
            Image { id: pic; x: 6; y: 6; width: 92; height: 92; source: root.picture; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false; sourceSize: Qt.size(184, 184) }
            Rectangle { id: mask; x: 6; y: 6; width: 92; height: 92; radius: 46; visible: false; layer.enabled: true }
            MultiEffect { x: 6; y: 6; width: 92; height: 92; source: pic; visible: pic.status === Image.Ready; maskEnabled: true; maskSource: mask }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 114
            text: root.realName
            font.family: root.fam; font.pixelSize: 24; font.weight: Font.Medium
            renderType: Text.QtRendering
            color: "#ffffff"
        }

        Item {
            id: fieldWrap
            width: 376; height: 58
            x: 32; y: 174
            SequentialAnimation {
                id: shake
                NumberAnimation { target: fieldWrap; property: "x"; to: 20; duration: 50 }
                NumberAnimation { target: fieldWrap; property: "x"; to: 44; duration: 80 }
                NumberAnimation { target: fieldWrap; property: "x"; to: 26; duration: 70 }
                NumberAnimation { target: fieldWrap; property: "x"; to: 32; duration: 60 }
            }
            Rectangle {
                anchors.fill: parent; radius: 29
                color: Qt.rgba(1, 1, 1, 0.12)
                border.width: root.failed ? 2 : 0
                border.color: config.WarningColor
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }
            TextInput {
                id: pw
                x: 26; width: parent.width - 26 - 68; height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "●"
                color: "transparent"; selectionColor: root.accent; font.family: root.fam; font.pixelSize: 18
                renderType: Text.QtRendering
                focus: true; enabled: !root.busy
                cursorDelegate: Item {}
                onAccepted: root.login()
                onTextChanged: root.failed = false
                Text {
                    visible: pw.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.failed ? "Wrong password" : "Password"
                    font: pw.font
                    color: root.failed ? config.WarningColor : Qt.rgba(1, 1, 1, 0.55)
                }
                // one shape per typed character, springing in and settling from the accent to white
                Flickable {
                    id: dots
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 28
                    visible: pw.text.length > 0
                    interactive: false; clip: true
                    contentWidth: dotRow.implicitWidth
                    contentX: Math.max(contentWidth - width, 0)
                    Behavior on contentX { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Row {
                        id: dotRow
                        anchors.left: parent.left; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Repeater {
                            model: pw.text.length
                            delegate: Item {
                                id: ch
                                required property int index
                                width: 14; height: 14
                                readonly property int kind: index % 5
                                Rectangle {
                                    id: blob
                                    anchors.centerIn: parent
                                    width: 0; height: 0; opacity: 0
                                    color: root.accent
                                    radius: ch.kind === 1 ? 3 : width / 2
                                    rotation: ch.kind === 1 ? 45 : 0
                                    property real full: ch.kind === 2 ? 18 : 15
                                    Component.onCompleted: appear.start()
                                    ParallelAnimation {
                                        id: appear
                                        NumberAnimation { target: blob; property: "opacity"; to: 1; duration: 50 }
                                        NumberAnimation { target: blob; property: "width"; to: blob.full; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                                        NumberAnimation { target: blob; property: "height"; to: ch.kind === 2 ? 9 : blob.full; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                                        ColorAnimation { target: blob; property: "color"; from: root.accent; to: "#ffffff"; duration: 1000; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 42; height: 42; radius: goMouse.containsMouse ? 16 : 21
                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                color: root.accent
                scale: goMouse.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "progress_activity" : "arrow_forward"
                    font.family: root.icons; font.pixelSize: 24; color: root.onAccent
                    RotationAnimator on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
            }
        }
    }
      Item { width: 1; height: 28 }
      Item {
        id: switchRow
        width: 440; height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        z: 5
    Row {
        id: leftRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        Rectangle {
            id: sessionPill
            height: 56; width: sessLabel.width + 100; radius: 28
            color: sessMouse.containsMouse || sessionPopup.visible ? root.accent : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: 160 } }
            Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "desktop_windows"; font.family: root.icons; font.pixelSize: 24
                color: sessMouse.containsMouse || sessionPopup.visible ? root.onAccent : "#ffffff" }
            Text { id: sessLabel; x: 52; anchors.verticalCenter: parent.verticalCenter; text: root.sessionName
                font.family: root.fam; font.pixelSize: 16; font.weight: Font.Medium; renderType: Text.QtRendering
                color: sessMouse.containsMouse || sessionPopup.visible ? root.onAccent : "#ffffff" }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                text: sessionPopup.visible ? "expand_more" : "expand_less"; font.family: root.icons; font.pixelSize: 20
                color: sessMouse.containsMouse || sessionPopup.visible ? root.onAccent : Qt.rgba(1, 1, 1, 0.7) }
            MouseArea { id: sessMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sessionPopup.visible = !sessionPopup.visible }
        }
        Round { icon: "keyboard"; tip: "On-screen keyboard"; onClicked: { vk.activated = !vk.activated; if (vk.activated) { pw.forceActiveFocus(); Qt.inputMethod.show() } } }
    }
    Rectangle {
        id: sessionPopup
        visible: false
        x: Math.round((parent.width - width) / 2); width: 280
        height: Math.min(sessionList.count, 8) * 52 + 16
        y: leftRow.height + 10
        radius: 26
        color: Qt.rgba(0.12, 0.2, 0.19, 0.94)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
        ListView {
            id: sessionList
            anchors.fill: parent; anchors.margins: 8
            clip: true; spacing: 0
            model: sessionModel
            delegate: Rectangle {
                id: srow
                width: sessionList.width; height: 52; radius: 20
                readonly property bool current: index === root.sessionIndex
                color: srowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : (current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28) : "transparent")
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: model.name; width: parent.width - 60; elide: Text.ElideRight
                    font.family: root.fam; font.pixelSize: 16; renderType: Text.QtRendering; color: "#ffffff" }
                Text { visible: srow.current; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    text: "check"; font.family: root.icons; font.pixelSize: 22; color: root.accent }
                MouseArea { id: srowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.sessionIndex = index; sessionPopup.visible = false; pw.forceActiveFocus() } }
            }
        }
    }

      }
    }

    // ---- bottom right: power, as round buttons straight on the wallpaper
    Row {
        id: pRow
        visible: sddm.canSuspend || sddm.canReboot || sddm.canPowerOff
        anchors { right: parent.right; bottom: parent.bottom; margins: 36 }
        spacing: 12
        Round { icon: "bedtime"; tip: "Sleep"; visible: sddm.canSuspend; onClicked: sddm.suspend() }
        Round { icon: "restart_alt"; tip: "Restart"; visible: sddm.canReboot; onClicked: sddm.reboot() }
        Round { icon: "power_settings_new"; tip: "Shut down"; visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
    }

    // ---- on-screen keyboard
    InputPanel {
        id: vk
        property bool activated: false
        z: 20
        width: Math.min(root.width - 200, 1000)
        x: (root.width - width) / 2
        y: activated && Qt.inputMethod.visible ? root.height - height - 120 : root.height
        visible: activated && Qt.inputMethod.visible
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
