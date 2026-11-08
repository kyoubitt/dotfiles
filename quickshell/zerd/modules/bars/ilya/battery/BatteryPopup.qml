import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../"
import "../reusables"

// The battery popup, our own: a drawn cell that fills with the charge, the time left or until full, three small facts
// (power draw, health, capacity), and the power profile as one segmented switch. Layout idea after Caelestia's battery popout.
Item {
    id: root
    visible: false
    width: 440
    readonly property real contentHeight: col.implicitHeight + 36
    implicitWidth: 440
    implicitHeight: contentHeight
    function startExit(done) { if (done) done() }

    readonly property var dev: UPower.displayDevice
    readonly property bool ready: dev.ready && dev.isLaptopBattery
    readonly property real level: ready ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property bool charging: ready && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: ready && dev.state === UPowerDeviceState.FullyCharged
    readonly property color tone: charging ? "#7bd88f" : (level < 0.15 ? "#ff6b63" : (level < 0.30 ? "#f5b85a" : ThemeBackend.blue))

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

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: ThemeBackend.liquidGlass ? ThemeBackend.card : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 1)
        border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.08)
    }

    ColumnLayout {
        id: col
        x: 18; y: 18
        width: parent.width - 36
        spacing: 16

        // the cell and the percentage
        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Item {
                Layout.preferredWidth: 132; Layout.preferredHeight: 64
                Rectangle {
                    id: shell
                    width: 122; height: 64; radius: 14
                    color: Qt.alpha(ThemeBackend.text, 0.06)
                    border.width: 3; border.color: Qt.alpha(root.tone, 0.9)
                    clip: true
                    Rectangle {
                        x: 6; y: 6
                        height: parent.height - 12
                        width: Math.max(8, (parent.width - 12) * root.level)
                        radius: 8
                        color: root.tone
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        visible: root.charging
                        anchors.centerIn: parent
                        text: "bolt"
                        font.family: "Material Symbols Rounded"
                        font.variableAxes: ({ "wght": 700, "opsz": 48, "FILL": 1 })
                        font.pixelSize: 34
                        color: ThemeBackend.crust
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle { x: 124; y: 20; width: 7; height: 24; radius: 3; color: Qt.alpha(root.tone, 0.9) }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: root.ready ? Math.round(root.level * 100) + "%" : "AC"
                    color: ThemeBackend.text
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 40; font.weight: Font.Black
                    font.features: { "tnum": 1 }
                    renderType: Text.NativeRendering
                }
                Text {
                    Layout.fillWidth: true
                    text: root.status
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Medium
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }

        // three small facts
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [
                    { k: "Power", v: root.ready ? Math.abs(root.dev.changeRate).toFixed(1) + " W" : "–", i: "bolt" },
                    { k: "Health", v: root.ready && root.dev.healthSupported ? Math.round(root.dev.healthPercentage) + "%" : "–", i: "favorite" },
                    { k: "Capacity", v: root.ready && root.dev.energyCapacity > 0 ? root.dev.energyCapacity.toFixed(0) + " Wh" : "–", i: "battery_full" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 14
                    color: Qt.tint(ThemeBackend.base, Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.07))
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5
                            Text {
                                text: modelData.i
                                font.family: "Material Symbols Rounded"
                                font.variableAxes: ({ "wght": 600, "opsz": 20 })
                                font.pixelSize: 15
                                color: ThemeBackend.blue
                                renderType: Text.NativeRendering
                            }
                            Text {
                                text: modelData.v
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 14; font.weight: Font.Bold
                                font.features: { "tnum": 1 }
                                renderType: Text.NativeRendering
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.k
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 12
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
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 21
                color: Qt.tint(ThemeBackend.base, Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.07))
                readonly property var items: PowerProfiles.hasPerformanceProfile
                    ? [{ p: PowerProfile.PowerSaver, t: "Saver", i: "eco" }, { p: PowerProfile.Balanced, t: "Balanced", i: "balance" }, { p: PowerProfile.Performance, t: "Performance", i: "speed" }]
                    : [{ p: PowerProfile.PowerSaver, t: "Saver", i: "eco" }, { p: PowerProfile.Balanced, t: "Balanced", i: "balance" }]
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
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = modelData.p }
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
