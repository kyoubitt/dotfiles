import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    function gotoTab(tabName) {
        if (!tabName) return;
        let t = tabName.toLowerCase();
        if (t === "output" || t === "outputs" || t === "sink" || t === "sinks") window.activeTab = "outputs";
        else if (t === "input" || t === "inputs" || t === "source" || t === "sources") window.activeTab = "inputs";
        else if (t === "app" || t === "apps" || t === "stream" || t === "streams") window.activeTab = "apps";
    }

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        introMain = 0;
        introHeader = 0;
        introContent = 0;
        introAnim.restart();
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.stop();
            introMain = 0;
            introHeader = 0;
            introContent = 0;
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: window.visible
        onActivated: {
            if (window.activeTab === "outputs") window.activeTab = "inputs";
            else if (window.activeTab === "inputs") window.activeTab = "apps";
            else window.activeTab = "outputs";
        }
    }

    property string activeTab: "outputs"
    onActiveTabChanged: {
        let newIndex = (activeTab === "outputs") ? 0 : ((activeTab === "inputs") ? 1 : 2);
        if (tabSwitch.currentIndex !== newIndex) {
            tabSwitch.currentIndex = newIndex;
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx(tabSwitch.switchSound);
            }
        }
    }

    readonly property color tabColor: {
        if (activeTab === "outputs") return ThemeBackend.blue;
        if (activeTab === "inputs") return ThemeBackend.mauve;
        return ThemeBackend.green;
    }

    readonly property string activeOutputName: Audio.activeOutputName

    readonly property string activeInputName: {
        const source = Audio.defaultSource;
        return source && source.name ? source.name : "";
    }

    readonly property PwNode activeNode: {
        if (window.activeTab === "inputs") {
            return Audio.defaultSource || (Audio.inputs.length > 0 ? Audio.inputs[0] : null);
        } else if (window.activeTab === "apps") {
            return Audio.apps.length > 0 ? Audio.apps[0] : null;
        } else {
            return Audio.defaultSink || (Audio.outputs.length > 0 ? Audio.outputs[0] : null);
        }
    }

    readonly property string activeName: {
        if (!activeNode) return I18n.t("volumepopup.no_device");
        if (activeTab === "apps") return Audio.getNodeAppName(activeNode);
        return Audio.friendlyName(activeNode);
    }

    readonly property string activeDesc: {
        if (!activeNode) return "";
        if (activeTab === "apps") return I18n.t("volumepopup.master_output_volume");
        return Audio.getNodeSubDesc(activeNode);
    }

    readonly property int activeVol: activeNode && activeNode.audio ? Math.round(activeNode.audio.volume * 100) : 0
    readonly property bool activeMute: activeNode && activeNode.audio ? activeNode.audio.muted : false

    readonly property string activeIcon: {
        if (!activeNode) return "󰓃";
        if (activeTab === "inputs") return "󰍬";
        if (activeTab === "apps") return "󰎆";
        let desc = (Audio.getNodeName(activeNode) || "").toLowerCase();
        if (desc.indexOf("headset") !== -1 || desc.indexOf("headphones") !== -1) return "󰋎";
        return "󰓃";
    }

    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    ParallelAnimation {
        id: introAnim
        running: false
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: window; property: "introHeader"; from: 0; to: 1.0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: window; property: "introContent"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: window; property: "introContent"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: window; property: "introHeader"; to: 0.0; duration: 160; easing.type: Easing.InBack }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: window; property: "introMain"; to: 0.0; duration: 150; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain
        transform: Translate { y: window.s(20) * (1 - introMain) }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.card
            clip: true

            GlassSheen {}

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: window.s(18)
                spacing: window.s(15)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(18)
                    opacity: introHeader
                    transform: Translate { y: window.s(25) * (1.0 - introHeader) }

                    // the level as one of the power menu's capsules: press and drag up or down, or scroll
                    PopupCapsule {
                        Layout.preferredWidth: 112; Layout.preferredHeight: 168
                        interactive: true
                        icon: window.activeMute || window.activeVol === 0 ? "volume_off" : (window.activeVol > 50 ? "volume_up" : "volume_down")
                        value: window.activeMute ? I18n.t("volumepopup.mute") : window.activeVol + "%"
                        caption: "Volume"
                        level: window.activeMute ? 0 : window.activeVol / 100
                        tone: window.activeMute ? ThemeBackend.red : window.tabColor
                        onMoved: f => {
                            if (!window.activeNode) return;
                            const pct = Math.round(f * 100);
                            if (pct > 0 && window.activeMute) Audio.toggleMute(window.activeNode);
                            Audio.setVolume(window.activeNode, pct);
                        }
                        onStepped: d => {
                            if (!window.activeNode) return;
                            const v = Math.max(0, Math.min(100, window.activeVol + d * 5));
                            if (v > 0 && window.activeMute) Audio.toggleMute(window.activeNode);
                            Audio.setVolume(window.activeNode, v);
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: window.s(4)
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: window.activeName
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(19); font.weight: Font.Bold
                            renderType: Text.NativeRendering
                        }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: window.activeDesc
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12)
                            renderType: Text.NativeRendering
                        }
                        Rectangle {
                            Layout.topMargin: window.s(10)
                            Layout.preferredHeight: window.s(36); Layout.preferredWidth: muteRow.implicitWidth + window.s(28)
                            radius: height / 2
                            color: window.activeMute ? Qt.alpha(ThemeBackend.red, 0.20) : Qt.alpha(ThemeBackend.text, muteMa.containsMouse ? 0.12 : 0.07)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Row {
                                id: muteRow
                                anchors.centerIn: parent; spacing: window.s(7)
                                Text {
                                    text: window.activeMute ? "volume_up" : "volume_off"
                                    font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                    font.pixelSize: window.s(18); color: window.activeMute ? ThemeBackend.red : ThemeBackend.text
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    text: window.activeMute ? "Unmute" : "Mute"
                                    font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(13); font.weight: Font.DemiBold
                                    color: window.activeMute ? ThemeBackend.red : ThemeBackend.text
                                    renderType: Text.NativeRendering
                                }
                            }
                            MouseArea { id: muteMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.playSfx("reusables/toggle/sfx.wav", 0.7); if (window.activeNode) Audio.toggleMute(window.activeNode) } }
                        }
                    }
                }

                Switch {
                    id: tabSwitch
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(38)
                    options: [I18n.t("volumepopup.tabs.outputs"), I18n.t("volumepopup.tabs.inputs"), I18n.t("volumepopup.tabs.streams")]
                    currentIndex: 0
                    cornerRadius: ThemeBackend.borderRadius
                    baseColor: ThemeBackend.surface0
                    accentColor: window.tabColor
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: window.s(12)
                    opacity: introHeader
                    transform: Translate { y: window.s(15) * (1.0 - introHeader) }

                    onValueChanged: function(index, value) {
                        if (index === 0) window.activeTab = "outputs";
                        else if (index === 1) window.activeTab = "inputs";
                        else window.activeTab = "apps";
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: introContent
                    transform: Translate { y: window.s(15) * (1.0 - introContent) }

                    ListView {
                        id: contentList
                        readonly property string tab: window.activeTab
                        readonly property string outputName: window.activeOutputName
                        readonly property string inputName: window.activeInputName
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        // outputs: the devices take what they need and the apps sit right under them; the other tabs fill the area
                        height: window.activeTab === "outputs" && Audio.apps.length > 0 ? Math.min(contentHeight, Math.max(window.s(100), parent.height - window.s(120))) : parent.height
                        spacing: window.s(10)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutQuint }
                            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 400; easing.type: Easing.OutBack }
                        }
                        displaced: Transition {
                            SpringAnimation { property: "y"; spring: 3; damping: 0.2; mass: 0.2 }
                        }

                        model: window.activeTab === "outputs" ? Audio.outputs : (window.activeTab === "inputs" ? Audio.inputs : Audio.apps)

                        Item {
                            width: contentList.width; height: contentList.height
                            visible: contentList.count === 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: window.s(8)
                                Text { Layout.alignment: Qt.AlignHCenter; font.family: ThemeBackend.iconFont; font.pixelSize: window.s(28); color: ThemeBackend.surface2; text: "󰖁" }
                                Text { Layout.alignment: Qt.AlignHCenter; font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(13); color: ThemeBackend.overlay0; text: I18n.t("volumepopup.no_active_streams") }
                            }
                        }

                        delegate: Rectangle {
                            id: delegateRoot
                            width: contentList.width

                            readonly property PwNode node: modelData
                            readonly property bool isActiveNode: !!ListView.view && (ListView.view.tab === "outputs" ? (!!node && node.name === ListView.view.outputName) : (ListView.view.tab === "inputs" ? (!!node && node.name === ListView.view.inputName) : false))
                            readonly property int nodeVol: node && node.audio ? Math.round(node.audio.volume * 100) : 0
                            readonly property bool nodeMute: node && node.audio ? node.audio.muted : false
                            readonly property string nodeDesc: !!ListView.view && ListView.view.tab === "apps" ? Audio.getNodeAppName(node) : Audio.friendlyName(node)
                            readonly property string nodeNameStr: Audio.getNodeSubDesc(node)

                            property bool isLoaded: false
                            Timer {
                                id: delegateEntranceTimer
                                running: window.visible
                                interval: 40 + (index * 40)
                                onTriggered: delegateRoot.isLoaded = true
                            }

                            Connections {
                                target: window
                                function onVisibleChanged() {
                                    if (!window.visible) {
                                        delegateRoot.isLoaded = false;
                                    } else {
                                        delegateEntranceTimer.restart();
                                    }
                                }
                            }

                            Component.onCompleted: {
                                if (window.visible) {
                                    delegateEntranceTimer.restart();
                                }
                            }

                            height: isActiveNode ? window.s(52) : window.s(88)
                            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                            opacity: isLoaded ? 1.0 : 0.0
                            transform: Translate { y: isLoaded ? 0 : window.s(12) }
                            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                            Behavior on transform { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                            radius: ThemeBackend.borderRadius

                            property bool isHovered: cardMa.containsMouse && !isActiveNode

                            color: delegateGlass.active ? "transparent" : (isActiveNode ? window.tabColor : (isHovered ? ThemeBackend.surface1 : ThemeBackend.surface0))
                            Behavior on color { ColorAnimation { duration: 250 } }

                            GlassFill {
                                id: delegateGlass
                                anchors.fill: parent
                                radius: parent.radius
                                tintColor: delegateRoot.isActiveNode ? window.tabColor : ThemeBackend.surface0
                                tintAmount: delegateRoot.isActiveNode ? 0.55 : 0.3
                                press: delegateRoot.isHovered ? 0.25 : 0
                                Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on tintAmount { NumberAnimation { duration: 250 } }
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: window.activeTab !== "apps"
                                cursorShape: window.activeTab !== "apps" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (window.activeTab !== "apps" && !delegateRoot.isActiveNode) {
                                        if (window.activeTab === "outputs") Audio.setDefaultOutput(delegateRoot.node);
                                        else if (window.activeTab === "inputs") Audio.setDefaultInput(delegateRoot.node);
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(12)
                                anchors.rightMargin: window.s(12)
                                anchors.topMargin: window.s(10)
                                anchors.bottomMargin: isActiveNode ? window.s(10) : window.s(12)
                                spacing: window.s(10)

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: window.s(10)

                                    Text {
                                        renderType: Text.NativeRendering
                                        font.family: ThemeBackend.iconFont; font.pixelSize: window.s(18)
                                        color: isActiveNode && !delegateGlass.active ? ThemeBackend.crust : ThemeBackend.text
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                        text: {
                                            if (window.activeTab === "inputs") return "󰍬";
                                            if (window.activeTab === "apps") return "󰎆";
                                            if (delegateRoot.nodeDesc.toLowerCase().indexOf("headset") !== -1 || delegateRoot.nodeDesc.toLowerCase().indexOf("headphones") !== -1) return "󰋎";
                                            return "󰓃";
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: window.s(2)
                                        Text {
                                            renderType: Text.NativeRendering
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                            font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(13)
                                            color: isActiveNode && !delegateGlass.active ? ThemeBackend.crust : ThemeBackend.text
                                            text: delegateRoot.nodeDesc
                                        }
                                        Text {
                                            renderType: Text.NativeRendering
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                            font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10.5)
                                            color: isActiveNode && !delegateGlass.active ? Qt.darker(ThemeBackend.crust, 1.5) : ThemeBackend.subtext0
                                            text: isActiveNode ? I18n.t("volumepopup.active_default") : delegateRoot.nodeNameStr
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: window.s(20)
                                    spacing: window.s(10)
                                    visible: !isActiveNode
                                    opacity: isActiveNode ? 0.0 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 250 } }

                                    IconButton {
                                        Layout.alignment: Qt.AlignVCenter
                                        size: window.s(24)
                                        cornerRadius: window.s(8)
                                        buttonIcon: delegateRoot.nodeMute || delegateRoot.nodeVol === 0 ? "󰖁" : (delegateRoot.nodeVol > 50 ? "󰕾" : "󰖀")
                                        iconFontSize: window.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (delegateRoot.nodeMute ? ThemeBackend.overlay0 : ThemeBackend.subtext0)
                                        onClicked: Audio.toggleMute(delegateRoot.node)
                                    }

                                    PopupSlider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: window.s(28)
                                        Layout.alignment: Qt.AlignVCenter
                                        value: delegateRoot.nodeVol
                                        muted: delegateRoot.nodeMute
                                        tone: window.tabColor
                                        onMoved: pct => {
                                            if (pct > 0 && delegateRoot.nodeMute) Audio.toggleMute(delegateRoot.node);
                                            Audio.setVolume(delegateRoot.node, pct);
                                        }
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.preferredWidth: window.s(30)
                                        Layout.alignment: Qt.AlignVCenter
                                        font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(11)
                                        color: ThemeBackend.subtext0
                                        text: delegateRoot.nodeVol + "%"
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    // per-app volume right under the output devices
                    Item {
                        id: appsBlock
                        visible: window.activeTab === "outputs" && Audio.apps.length > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: contentList.bottom
                        anchors.topMargin: window.s(12)
                        anchors.bottom: parent.bottom

                        Text {
                            id: appsTitle
                            renderType: Text.NativeRendering
                            text: "Apps"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: ThemeBackend.subtext0
                        }

                        ListView {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: appsTitle.bottom
                            anchors.topMargin: window.s(8)
                            anchors.bottom: parent.bottom
                            clip: true
                            spacing: window.s(6)
                            boundsBehavior: Flickable.StopAtBounds
                            model: Audio.apps

                            delegate: Rectangle {
                                id: appRow
                                required property var modelData
                                width: ListView.view.width
                                height: window.s(40)
                                radius: window.s(12)
                                color: ThemeBackend.surface0
                                readonly property int vol: modelData && modelData.audio ? Math.round(modelData.audio.volume * 100) : 0
                                readonly property bool muted: modelData && modelData.audio ? modelData.audio.muted : false

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(12)
                                    anchors.rightMargin: window.s(12)
                                    spacing: window.s(10)
                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.preferredWidth: window.s(96)
                                        elide: Text.ElideRight
                                        text: Audio.getNodeAppName(appRow.modelData)
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: appRow.muted ? ThemeBackend.subtext0 : ThemeBackend.text
                                    }
                                    PopupSlider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: window.s(28)
                                        Layout.alignment: Qt.AlignVCenter
                                        value: appRow.vol
                                        muted: appRow.muted
                                        tone: window.tabColor
                                        onMoved: pct => {
                                            if (pct > 0 && appRow.muted) Audio.toggleMute(appRow.modelData);
                                            Audio.setVolume(appRow.modelData, pct);
                                        }
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.preferredWidth: window.s(34)
                                        horizontalAlignment: Text.AlignRight
                                        text: appRow.vol + "%"
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        font.features: { "tnum": 1 }
                                        color: ThemeBackend.subtext0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
