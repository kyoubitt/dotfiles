import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Io
import "../"
import "../reusables"

// The battery popup, our own: a drawn cell that fills with the charge, the time left or until full, three small facts
// (power draw, health, capacity), and the power profile as one segmented switch. Layout idea after Caelestia's battery popout.
Item {
    id: root
    visible: false
    width: 440
    implicitWidth: 440
    implicitHeight: contentHeight
    function startExit(done) { if (done) done() }

    readonly property var dev: UPower.displayDevice
    readonly property bool ready: dev.ready && dev.isLaptopBattery
    readonly property real level: ready ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property bool charging: ready && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: ready && dev.state === UPowerDeviceState.FullyCharged
    property color tone: charging ? "#7bd88f" : (level < 0.15 ? "#ff6b63" : (level < 0.30 ? "#f5b85a" : ThemeBackend.blue))

    // wear from the sysfs counters: UPower leaves health unset on this laptop
    FileView { id: fFull; path: "/sys/class/power_supply/BAT1/charge_full"; blockLoading: true }
    FileView { id: fDesign; path: "/sys/class/power_supply/BAT1/charge_full_design"; blockLoading: true }
    FileView { id: fCycles; path: "/sys/class/power_supply/BAT1/cycle_count"; blockLoading: true }
    readonly property real wFull: parseFloat(fFull.text()) / 1e6
    readonly property real wDesign: parseFloat(fDesign.text()) / 1e6
    readonly property string healthText: root.dev.healthSupported ? Math.round(root.dev.healthPercentage) + "%"
        : (wDesign > 0 ? Math.round(wFull / wDesign * 100) + "%" : "–")
    readonly property string capText: dev.energyCapacity > 0 ? (wDesign > 0 && wFull > 0 ? dev.energyCapacity.toFixed(0) + " / " + (dev.energyCapacity * wDesign / wFull).toFixed(0) + " Wh" : dev.energyCapacity.toFixed(0) + " Wh") : "–"
    readonly property string cycleText: parseInt(fCycles.text()) > 0 ? parseInt(fCycles.text()) + "" : "–"

    Behavior on tone { ColorAnimation { duration: 400 } }
    property real shownLevel: 0
    Behavior on shownLevel { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    onLevelChanged: shownLevel = level
    onVisibleChanged: if (visible) { shownLevel = 0; shownLevel = level }

    function span(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        if (h > 0) return h + " h " + m + " min";
        return Math.max(1, m) + " min";
    }
    readonly property string status: {
        if (!ready) return "No battery detected";
        if (full) return "Fully charged";
        if (charging) return dev.timeToFull > 0 ? "Charging · " + span(dev.timeToFull) + " until full" : "Charging";
        return dev.timeToEmpty > 0 ? "On battery · " + span(dev.timeToEmpty) + " left" : "On battery";
    }

    readonly property real contentHeight: 334 + col.implicitHeight + 18
    property real orbit: 0
    NumberAnimation on orbit { from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: root.visible }
    property real drift: 0
    NumberAnimation on drift { from: 0; to: Math.PI * 2; duration: 160000; loops: Animation.Infinite; running: root.visible }

    Rectangle {
        id: card
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

        // slow drifting colour behind everything
        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.drift * 2) * 110
            y: 130 - height / 2 + Math.sin(root.drift * 2) * 60
            color: root.tone; opacity: 0.07
        }
        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.drift * 1.5) * -110
            y: 150 - height / 2 + Math.cos(root.drift * 1.5) * -60
            color: ThemeBackend.surface2; opacity: 0.05
        }

        // the scene: two orbit rings, the core, three satellites
        Item {
            id: scene
            x: 0; y: 0; width: parent.width; height: 334
            readonly property real cx: width / 2
            readonly property real cy: 154

            Rectangle { x: scene.cx - 92; y: scene.cy - 92; width: 184; height: 184; radius: 92; color: "transparent"; border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.07) }
            Rectangle { x: scene.cx - 142; y: scene.cy - 104; width: 284; height: 208; radius: 104; color: "transparent"; border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.05) }

            // breathing halo while charging
            Rectangle {
                id: halo
                anchors.centerIn: core
                width: core.width + 22; height: width; radius: width / 2
                color: "transparent"; border.width: 1.5; border.color: root.tone
                opacity: 0.12 + (root.charging ? 0.10 * Math.sin(root.orbit * 900) : 0)
            }

            Rectangle {
                id: core
                x: scene.cx - 68; y: scene.cy - 68
                width: 136; height: 136; radius: 68
                color: ThemeBackend.base
                border.width: 2; border.color: Qt.lighter(root.tone, 1.1)
                clip: true

                FluidWave {
                    id: wave
                    anchors.fill: parent
                    property real wavePhase: 0
                    NumberAnimation on wavePhase { running: root.visible; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 2600 }
                    radius: core.radius
                    fillLevel: root.shownLevel
                    waveAmp: fillLevel < 0.99 ? 5 * Math.sin(fillLevel * Math.PI) : 0
                    phase: wavePhase
                    vertical: 1.0
                    color1: Qt.lighter(root.tone, 1.15)
                    color2: root.tone
                    visible: root.shownLevel > 0.01
                }
                Text {
                    anchors.centerIn: parent
                    text: root.ready ? Math.round(root.level * 100) + "%" : "AC"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: 32
                    renderType: Text.NativeRendering
                }
                Item {
                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                    height: Math.min(parent.height, Math.max(0, parent.height * root.shownLevel - 0.375 * wave.waveAmp * (Math.sin(wave.wavePhase) - Math.cos(wave.wavePhase))))
                    clip: true
                    Text {
                        width: core.width; height: core.height
                        y: -(core.height - parent.height)
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: root.ready ? Math.round(root.level * 100) + "%" : "AC"
                        color: ThemeBackend.crust
                        font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: 32
                        renderType: Text.NativeRendering
                    }
                }
            }

            // satellites drift slowly round the outer ring
            Repeater {
                model: [
                    { k: "Power", v: root.ready ? Math.abs(root.dev.changeRate).toFixed(1) + " W" : "–", i: "bolt", a: -2.1 },
                    { k: "Health", v: root.ready ? root.healthText : "–", i: "favorite", a: 0.0 },
                    { k: "Capacity", v: root.ready ? root.capText : "–", i: "battery_full", a: 2.1 }
                ]
                delegate: Item {
                    id: sat
                    required property var modelData
                    width: 66; height: 66
                    required property int index
                    property real appear: 0
                    opacity: appear
                    scale: (0.6 + 0.4 * appear) * (satMa.containsMouse ? 1.08 : 1)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    SequentialAnimation on appear {
                        running: root.visible
                        PropertyAction { value: 0 }
                        PauseAnimation { duration: 120 + sat.index * 90 }
                        NumberAnimation { to: 1; duration: 520; easing.type: Easing.OutBack }
                    }
                    MouseArea { id: satMa; anchors.fill: parent; hoverEnabled: true }
                    x: scene.cx - width / 2 + Math.cos(modelData.a + root.orbit * 6) * 142
                    y: scene.cy - height / 2 + Math.sin(modelData.a + root.orbit * 6) * 104
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        color: Qt.alpha(ThemeBackend.surface0, 0.92)
                        border.width: 1.5; border.color: Qt.alpha(root.tone, 0.55)
                        Column {
                            anchors.centerIn: parent; spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sat.modelData.i
                                font.family: "Material Symbols Rounded"
                                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                                font.pixelSize: 16; color: root.tone
                                renderType: Text.NativeRendering
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sat.modelData.v
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily; font.pixelSize: sat.modelData.v.length > 6 ? 10 : 12; font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                    Text {
                        anchors.top: parent.bottom; anchors.topMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: sat.modelData.k
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        // status line under the scene
        Text {
            x: 18; y: 306; width: parent.width - 36
            horizontalAlignment: Text.AlignHCenter
            text: root.status
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    ColumnLayout {
        id: col
        x: 18; y: 334
        width: parent.width - 36
        spacing: 12

        // power profile: one segmented switch with a sliding highlight
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "Power profile"
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase
                renderType: Text.NativeRendering
            }
            Rectangle {
                id: seg
                property string pending: ""
                Process { id: setter }
                function choose(name, p) {
                    pending = name
                    PowerProfiles.profile = p
                    setter.command = ["powerprofilesctl", "set", name]
                    setter.running = true
                }
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 21
                color: Qt.tint(ThemeBackend.base, Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.07))
                readonly property var items: PowerProfiles.hasPerformanceProfile
                    ? [{ p: PowerProfile.PowerSaver, n: "power-saver", t: "Saver", i: "eco" }, { p: PowerProfile.Balanced, n: "balanced", t: "Balanced", i: "balance" }, { p: PowerProfile.Performance, n: "performance", t: "Performance", i: "speed" }]
                    : [{ p: PowerProfile.PowerSaver, n: "power-saver", t: "Saver", i: "eco" }, { p: PowerProfile.Balanced, n: "balanced", t: "Balanced", i: "balance" }]
                readonly property int idx: Math.max(0, items.findIndex(x => x.p === PowerProfiles.profile))
                Rectangle {
                    y: 4; height: parent.height - 8; radius: height / 2
                    width: (parent.width - 8) / seg.items.length
                    x: 4 + seg.idx * width
                    color: ThemeBackend.blue
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
                Repeater {
                    model: seg.items
                    delegate: Item {
                        required property var modelData
                        required property int index
                        x: 4 + index * (seg.width - 8) / seg.items.length; y: 4
                        width: (seg.width - 8) / seg.items.length; height: seg.height - 8
                        readonly property bool on: PowerProfiles.profile === modelData.p
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.i
                                font.family: "Material Symbols Rounded"
                                font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                font.pixelSize: 16
                                color: on ? ThemeBackend.crust : ThemeBackend.subtext0
                                renderType: Text.NativeRendering
                            }
                            Text {
                                text: modelData.t
                                color: on ? ThemeBackend.crust : ThemeBackend.text
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.choose(modelData.n, modelData.p) }
                    }
                }
            }
        }

        // the charger or the heat is holding the machine back
        Rectangle {
            visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 40 : 0
            radius: 12
            color: Qt.alpha("#ff6b63", 0.18)
            Row {
                anchors.centerIn: parent
                spacing: 8
                Text { text: "warning"; font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 600, "opsz": 20 }); font.pixelSize: 18; color: "#ff6b63"; renderType: Text.NativeRendering }
                Text {
                    text: PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature ? "Performance limited: the device is hot" : "Performance limited"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
