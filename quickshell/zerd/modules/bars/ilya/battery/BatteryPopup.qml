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

    readonly property real contentHeight: 18 + capsRow.height + 14 + info.height + 14 + col.implicitHeight + 18

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
    }

    // the power menu's capsules: charge, battery health, power draw
    Row {
        id: capsRow
        x: 18; y: 18
        spacing: 12
        readonly property real w: (root.width - 36 - 24) / 3
        PopupCapsule {
            width: capsRow.w; height: 168
            icon: root.charging ? "battery_charging_full" : "battery_full"
            value: root.ready ? Math.round(root.level * 100) + "%" : "AC"
            caption: "Charge"
            level: root.level
            tone: root.tone
        }
        PopupCapsule {
            width: capsRow.w; height: 168
            icon: "favorite"
            value: root.ready ? root.healthText : "–"
            caption: "Health"
            level: root.ready ? (parseFloat(root.healthText) || 0) / 100 : 0
            tone: ThemeBackend.blue
        }
        PopupCapsule {
            readonly property real watts: root.ready ? Math.abs(root.dev.changeRate) : 0
            readonly property bool onAc: root.ready && watts < 0.05 && root.dev.state !== UPowerDeviceState.Discharging
            width: capsRow.w; height: 168
            icon: onAc ? "power" : "bolt"
            value: !root.ready ? "–" : (onAc ? "On AC" : watts.toFixed(1) + " W")
            caption: root.charging && !onAc ? "Charging" : (onAc ? "Plugged in" : "Draw")
            level: onAc ? 1 : Math.min(1, watts / 30)
            tone: onAc ? "#7bd88f" : ThemeBackend.blue
        }
    }

    Item {
        id: info
        x: 22; y: 18 + 168 + 14
        width: parent.width - 44
        height: 44
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: !root.ready ? "No battery" : (root.full ? "Fully charged" : (root.charging ? "Charging" : "On battery"))
                color: root.tone
                font.family: ThemeBackend.fontFamily; font.pixelSize: 18; font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
            Text {
                text: root.status.indexOf("\u00B7") >= 0 ? root.status.substring(root.status.indexOf("\u00B7") + 2) : (root.full ? "Nothing left to charge" : "")
                visible: text !== ""
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily; font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }
        Column {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                anchors.right: parent.right
                text: root.capText
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }
            Text {
                anchors.right: parent.right
                text: "capacity"
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }
    }

    ColumnLayout {
        id: col
        x: 18; y: 18 + 168 + 14 + info.height + 14
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
                Connections { target: PowerProfiles; function onProfileChanged() { seg.pending = "" } }
                Process { id: setter }
                function choose(name, p) {
                    Sounds.playSfx("reusables/switch/sfx.wav", 0.7)
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
                readonly property int idx: Math.max(0, items.findIndex(x => pending !== "" ? x.n === pending : x.p === PowerProfiles.profile))
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
                        readonly property bool on: seg.pending !== "" ? seg.pending === modelData.n : PowerProfiles.profile === modelData.p
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
