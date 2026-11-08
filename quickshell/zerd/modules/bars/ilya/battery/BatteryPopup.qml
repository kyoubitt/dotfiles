import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Io
import qs.services as Svc
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

    readonly property real contentHeight: 318 + col.implicitHeight + 18
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
            x: 0; y: 0; width: parent.width; height: 318
            readonly property real cx: width / 2
            readonly property real cy: 154

            Rectangle { x: scene.cx - 92; y: scene.cy - 92; width: 184; height: 184; radius: 92; color: "transparent"; border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.07) }
            Rectangle { x: scene.cx - 142; y: scene.cy - 142; width: 284; height: 284; radius: 142; color: "transparent"; border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.05) }

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
                    y: scene.cy - height / 2 + Math.sin(modelData.a + root.orbit * 6) * 142 * 0.78
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
            x: 18; y: 280; width: parent.width - 36
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
        x: 18; y: 318
        width: parent.width - 36
        spacing: 12

        // the last twelve hours: charge as an area, charging stretches shaded green, power draw as a thin line
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Last 12 hours"
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                    font.letterSpacing: 0.6; font.capitalization: Font.AllUppercase
                    renderType: Text.NativeRendering
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 12
                    Row { spacing: 5; Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: root.tone } Text { text: "Charge"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0; renderType: Text.NativeRendering } }
                    Row { spacing: 5; Rectangle { width: 8; height: 3; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: ThemeBackend.text; opacity: 0.7 } Text { text: "Power"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0; renderType: Text.NativeRendering } }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: 16
                color: Qt.alpha(ThemeBackend.text, 0.05)
                clip: true
                Canvas {
                    id: chart
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 12; bottomMargin: 24 }
                    renderTarget: Canvas.FramebufferObject
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const span = 12 * 3600 * 1000, now = Date.now(), t0 = now - span;
                        const pts = Svc.BatteryHistory.points.filter(x => x.t >= t0);
                        const X = t => (t - t0) / span * width;
                        const Y = v => height - Math.max(0, Math.min(1, v)) * (height - 4) - 2;
                        const tc = root.tone, tx = ThemeBackend.text, gr = Qt.color("#7bd88f");
                        // faint grid
                        ctx.lineWidth = 1; ctx.strokeStyle = Qt.rgba(tx.r, tx.g, tx.b, 0.07);
                        for (const g of [0.25, 0.5, 0.75]) { ctx.beginPath(); ctx.moveTo(0, Y(g)); ctx.lineTo(width, Y(g)); ctx.stroke(); }
                        if (pts.length < 2) {
                            ctx.fillStyle = Qt.rgba(tx.r, tx.g, tx.b, 0.45);
                            ctx.font = "12px sans-serif"; ctx.textAlign = "center";
                            ctx.fillText("Collecting data, a sample every 2 minutes", width / 2, height / 2);
                            return;
                        }
                        // charging stretches
                        ctx.fillStyle = Qt.rgba(gr.r, gr.g, gr.b, 0.13);
                        let start = -1;
                        for (let i = 0; i < pts.length; i++) {
                            if (pts[i].c && start < 0) start = X(pts[i].t);
                            if ((!pts[i].c || i === pts.length - 1) && start >= 0) { ctx.fillRect(start, 0, Math.max(2, X(pts[i].t) - start), height); start = -1; }
                        }
                        // charge area
                        const grad = ctx.createLinearGradient(0, 0, 0, height);
                        grad.addColorStop(0, Qt.rgba(tc.r, tc.g, tc.b, 0.45)); grad.addColorStop(1, Qt.rgba(tc.r, tc.g, tc.b, 0.03));
                        ctx.beginPath(); ctx.moveTo(X(pts[0].t), height);
                        for (const q of pts) ctx.lineTo(X(q.t), Y(q.p));
                        ctx.lineTo(X(pts[pts.length - 1].t), height); ctx.closePath();
                        ctx.fillStyle = grad; ctx.fill();
                        ctx.beginPath();
                        pts.forEach((q, i) => { if (i === 0) ctx.moveTo(X(q.t), Y(q.p)); else ctx.lineTo(X(q.t), Y(q.p)); });
                        ctx.lineWidth = 2.2; ctx.lineJoin = "round"; ctx.strokeStyle = Qt.rgba(tc.r, tc.g, tc.b, 1); ctx.stroke();
                        // power draw, scaled to its own peak
                        const wmax = Math.max(5, ...pts.map(q => q.w));
                        ctx.beginPath();
                        pts.forEach((q, i) => { if (i === 0) ctx.moveTo(X(q.t), Y(q.w / wmax)); else ctx.lineTo(X(q.t), Y(q.w / wmax)); });
                        ctx.lineWidth = 1.2; ctx.strokeStyle = Qt.rgba(tx.r, tx.g, tx.b, 0.55); ctx.stroke();
                        // the latest point
                        const last = pts[pts.length - 1];
                        ctx.beginPath(); ctx.arc(X(last.t), Y(last.p), 4, 0, Math.PI * 2);
                        ctx.fillStyle = Qt.rgba(tc.r, tc.g, tc.b, 1); ctx.fill();
                    }
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    Connections { target: Svc.BatteryHistory; function onPointsChanged() { if (root.visible) chart.requestPaint() } }
                    Connections { target: root; function onVisibleChanged() { if (root.visible) chart.requestPaint() } }
                }
                Row {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 6 }
                    Repeater {
                        model: ["12 h ago", "9 h", "6 h", "3 h", "now"]
                        delegate: Text {
                            required property string modelData
                            required property int index
                            width: parent.width / 5
                            horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 4 ? Text.AlignRight : Text.AlignHCenter)
                            text: modelData
                            color: ThemeBackend.subtext0; opacity: 0.8
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 11
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

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
