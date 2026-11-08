import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services as Svc
import "../"
import "../reusables"

// The battery on its own: the cell filling with the charge, percentage, time left, power draw, health and cycles,
// the power profile, the last 24 hours of charge, and the brightness, do-not-disturb and night-light shortcuts.
Item {
    id: root
    visible: false

    property real intro: 0
    property var exitCallback: null
    readonly property real contentHeight: col.implicitHeight + 28

    function startExit(onFinished) { exitCallback = onFinished; introAnim.stop(); outAnim.restart(); }
    function resetAndPlayIntro() { outAnim.stop(); intro = 0; introAnim.restart(); }
    onVisibleChanged: {
        if (visible) { resetAndPlayIntro(); readout.running = true; BatteryHistory.sample(); console.log("BATDBG open present", hasBattery, "pct", pct, "charging", charging, "history", BatteryHistory.points.length) /* TEMP DEBUG */ }
        else { introAnim.stop(); outAnim.stop(); intro = 0; }
    }
    NumberAnimation { id: introAnim; target: root; property: "intro"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: 160; easing.type: Easing.InCubic }
        ScriptAction { script: { if (root.exitCallback) { const cb = root.exitCallback; root.exitCallback = null; cb(); } } }
    }

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev.ready && dev.isLaptopBattery
    readonly property int pct: hasBattery ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: hasBattery && dev.state === UPowerDeviceState.FullyCharged
    readonly property color level: charging ? ThemeBackend.green : (pct <= 20 ? ThemeBackend.red : (pct <= 40 ? ThemeBackend.yellow : ThemeBackend.blue))
    readonly property real secs: hasBattery ? (charging ? dev.timeToFull : dev.timeToEmpty) : 0
    readonly property string timeText: {
        if (!hasBattery) return "No battery";
        if (full) return "Fully charged";
        if (secs <= 0) return charging ? "Charging" : "On battery";
        const h = Math.floor(secs / 3600), m = Math.round(secs % 3600 / 60);
        return (h > 0 ? h + "h " : "") + m + "m " + (charging ? "until full" : "left");
    }
    readonly property int profileIndex: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : (PowerProfiles.profile === PowerProfile.Performance ? 2 : 1)

    // power draw and cycle count come from sysfs
    property real watts: 0
    property int cycles: -1
    Process {
        id: readout
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1; echo '---'; cat /sys/class/power_supply/BAT*/cycle_count 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n");
                const pw = Number((parts[0] ?? "").trim());
                root.watts = isNaN(pw) ? 0 : pw / 1e6;
                const cy = parseInt((parts[1] ?? "").trim());
                root.cycles = isNaN(cy) ? -1 : cy;
            }
        }
    }
    Timer { interval: 4000; repeat: true; running: root.visible; onTriggered: readout.running = true }

    component Section: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 28
        radius: ThemeBackend.borderRadius - 4
        color: ThemeBackend.surface0
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
        }
    }
    component Label: Text {
        renderType: Text.NativeRendering
        font.family: ThemeBackend.fontFamily
        font.pixelSize: 13
        color: ThemeBackend.subtext0
    }
    component Chip: Rectangle {
        id: chip
        property string symbol
        property string label
        property bool on: false
        signal tapped()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 40
        radius: 12
        color: on ? ThemeBackend.blue : (cm.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                text: chip.symbol
                font.family: ThemeBackend.symbolFont
                font.variableAxes: ({ "wght": 600, "opsz": 20 })
                font.pixelSize: 18
                color: chip.on ? ThemeBackend.crust : ThemeBackend.text
            }
            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: chip.on ? ThemeBackend.crust : ThemeBackend.text
            }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.playSfx("reusables/toggle/sfx.wav", 0.6); chip.tapped() } }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.base
        opacity: root.intro
        scale: 0.96 + 0.04 * root.intro
        transformOrigin: Item.TopRight
        clip: true

        GlassSheen {}

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Text {
                renderType: Text.NativeRendering
                text: "Battery"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: ThemeBackend.text
            }

            // the cell, the charge and the numbers
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Item {
                        Layout.preferredWidth: 86
                        Layout.preferredHeight: 42
                        Rectangle {
                            id: shell
                            width: parent.width - 7
                            height: parent.height
                            radius: 11
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(ThemeBackend.text, 0.5)
                            Rectangle {
                                x: 4; y: 4
                                height: parent.height - 8
                                width: Math.max(height, (parent.width - 8) * root.pct / 100)
                                radius: 7
                                color: root.level
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                visible: root.charging
                                text: "bolt"
                                font.family: ThemeBackend.symbolFont
                                font.variableAxes: ({ "wght": 600, "opsz": 24 })
                                font.pixelSize: 26
                                color: ThemeBackend.crust
                            }
                        }
                        Rectangle {
                            x: shell.width + 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5; height: 16; radius: 2.5
                            color: Qt.alpha(ThemeBackend.text, 0.5)
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            renderType: Text.NativeRendering
                            text: root.hasBattery ? root.pct + "%" : "--"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 36
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: ThemeBackend.text
                        }
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: root.timeText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 13
                            color: ThemeBackend.subtext0
                        }
                    }
                }
                RowLayout {
                    visible: root.hasBattery
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { c: "Power", v: root.watts > 0 ? root.watts.toFixed(1) + " W" : "-" },
                            { c: "Health", v: root.dev.healthSupported ? Math.round(root.dev.healthPercentage) + "%" : "-" },
                            { c: "Cycles", v: root.cycles >= 0 ? String(root.cycles) : "-" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 54
                            radius: 12
                            color: ThemeBackend.surface1
                            Column {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { renderType: Text.NativeRendering; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.v; font.family: ThemeBackend.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; font.features: { "tnum": 1 }; color: ThemeBackend.text }
                                Text { renderType: Text.NativeRendering; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.c; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0 }
                            }
                        }
                    }
                }
            }

            // power profile
            Section {
                Label { text: "Power profile" }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 19
                    color: ThemeBackend.surface1
                    readonly property var names: PowerProfiles.hasPerformanceProfile ? ["Saver", "Balanced", "Performance"] : ["Saver", "Balanced"]
                    readonly property real segW: width / names.length
                    Rectangle {
                        y: 3; height: parent.height - 6
                        width: parent.segW - 6
                        x: 3 + Math.min(root.profileIndex, parent.names.length - 1) * parent.segW
                        radius: height / 2
                        color: ThemeBackend.blue
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Repeater {
                        model: parent.names
                        delegate: Item {
                            required property string modelData
                            required property int index
                            x: index * parent.segW; width: parent.segW; height: parent.height
                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: root.profileIndex === index ? ThemeBackend.crust : ThemeBackend.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/switch/sfx.wav", 0.6); PowerProfiles.profile = index === 0 ? PowerProfile.PowerSaver : (index === 1 ? PowerProfile.Balanced : PowerProfile.Performance) }
                            }
                        }
                    }
                }
            }

            // last 24 hours
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Last 24 hours" }
                    Item { Layout.fillWidth: true }
                    Label { text: BatteryHistory.points.length > 1 ? "" : "collecting"; font.pixelSize: 12 }
                }
                Item {
                    id: graph
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    readonly property int slots: 96                       // 15 minutes each
                    readonly property real step: width / slots
                    readonly property real tEnd: Date.now()
                    function valueAt(slot) {
                        // the last known point inside this slot's quarter hour
                        const from = Date.now() - (slots - slot) * 900000, to = from + 900000;
                        let best = null;
                        for (const p of BatteryHistory.points) if (p.t >= from && p.t < to) best = p;
                        return best;
                    }
                    Rectangle { anchors.fill: parent; radius: 8; color: ThemeBackend.surface1 }
                    // the 50 % guide
                    Rectangle { x: 0; width: parent.width; y: parent.height / 2; height: 1; color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.1) }
                    Repeater {
                        model: graph.slots
                        delegate: Item {
                            required property int index
                            readonly property var pt: BatteryHistory.points.length > 0 ? graph.valueAt(index) : null
                            x: index * graph.step
                            width: graph.step
                            height: graph.height
                            Rectangle {
                                visible: parent.pt !== null
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(1, parent.width - 1)
                                height: parent.pt ? Math.max(2, (parent.height - 4) * parent.pt.p / 100) : 0
                                radius: 1
                                color: parent.pt && parent.pt.c ? ThemeBackend.green : (parent.pt && parent.pt.p <= 20 ? ThemeBackend.red : ThemeBackend.blue)
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "24 h ago"; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Label { text: "12 h"; font.pixelSize: 11 }
                    Item { Layout.fillWidth: true }
                    Label { text: "now"; font.pixelSize: 11 }
                }
            }

            // brightness and shortcuts
            Section {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        renderType: Text.NativeRendering
                        text: "brightness_6"
                        font.family: ThemeBackend.symbolFont
                        font.variableAxes: ({ "wght": 600, "opsz": 20 })
                        font.pixelSize: 18
                        color: ThemeBackend.subtext0
                    }
                    Draggable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        Layout.alignment: Qt.AlignVCenter
                        from: 0.0
                        to: 100.0
                        value: OsdController.sysBrightness
                        backgroundColor: ThemeBackend.surface2
                        accentColor: ThemeBackend.blue
                        gradColor1: ThemeBackend.blue
                        gradColor2: Qt.lighter(ThemeBackend.blue, 1.05)
                        gradColor3: Qt.lighter(ThemeBackend.blue, 1.10)
                        cornerRadius: 5
                        handleSize: 18
                        handleColor: Qt.lighter(ThemeBackend.blue, 1.15)
                        handleHoverColor: Qt.lighter(ThemeBackend.blue, 1.5)
                        handleDragColor: Qt.lighter(ThemeBackend.blue, 1.45)
                        handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                        onMoved: val => OsdController.setBrightness(Math.max(5, Math.min(100, Math.round(val))))
                    }
                    Text {
                        renderType: Text.NativeRendering
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                        text: OsdController.sysBrightness + "%"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        font.features: { "tnum": 1 }
                        color: ThemeBackend.subtext0
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Chip {
                        symbol: Svc.Notifications.silent ? "notifications_off" : "notifications"
                        label: "Do not disturb"
                        on: Svc.Notifications.silent
                        onTapped: Svc.Notifications.toggleSilent()
                    }
                    Chip {
                        symbol: "bedtime"
                        label: "Night light"
                        on: Svc.Hyprsunset.active
                        onTapped: Svc.Hyprsunset.toggle()
                    }
                }
            }
        }
    }

}
