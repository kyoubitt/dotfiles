import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../"

// The battery: a drawn cell that fills with the charge, the big percentage, time left and health, and the power profile as a three-way switch.
Rectangle {
    id: card

    required property var panel
    readonly property bool hasBattery: !panel.isDesktop && UPower.displayDevice.ready
    readonly property int pct: panel.batCapacity
    readonly property bool charging: panel.isCharging
    readonly property color level: charging ? ThemeBackend.green : (pct <= 20 ? ThemeBackend.red : (pct <= 40 ? ThemeBackend.yellow : ThemeBackend.blue))
    readonly property int profileIndex: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : (PowerProfiles.profile === PowerProfile.Performance ? 2 : 1)
    readonly property real health: (UPower.displayDevice.healthPercentage ?? 0)

    radius: panel.s(16)
    color: ThemeBackend.surface0
    Layout.fillWidth: true
    Layout.preferredHeight: hasBattery ? panel.s(132) : panel.s(64)
    Layout.maximumHeight: Layout.preferredHeight
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: panel.s(14)
        spacing: panel.s(12)

        RowLayout {
            visible: card.hasBattery
            Layout.fillWidth: true
            spacing: panel.s(14)

            // the cell
            Item {
                Layout.preferredWidth: panel.s(64)
                Layout.preferredHeight: panel.s(30)
                Rectangle {
                    id: shell
                    width: parent.width - panel.s(5)
                    height: parent.height
                    radius: panel.s(8)
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.alpha(ThemeBackend.text, 0.5)
                    Rectangle {
                        x: 3; y: 3
                        height: parent.height - 6
                        width: Math.max(height, (parent.width - 6) * card.pct / 100)
                        radius: panel.s(5)
                        color: card.level
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        renderType: Text.NativeRendering
                        anchors.centerIn: parent
                        visible: card.charging
                        text: "bolt"
                        font.family: ThemeBackend.symbolFont
                        font.pixelSize: panel.s(20)
                        color: ThemeBackend.crust
                    }
                }
                Rectangle {
                    x: shell.width + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: panel.s(4); height: panel.s(12); radius: 2
                    color: Qt.alpha(ThemeBackend.text, 0.5)
                }
            }

            Text {
                renderType: Text.NativeRendering
                text: card.pct + "%"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: panel.s(28)
                font.weight: Font.Bold
                color: ThemeBackend.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: panel.batStatus + ((panel.batHours > 0 || panel.batMins > 0) && panel.batTimeLabel !== "" ? "  " + panel.batHours + "h " + panel.batMins + "m " + panel.batTimeLabel : "")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panel.s(13)
                    color: ThemeBackend.text
                }
                Text {
                    renderType: Text.NativeRendering
                    visible: card.health > 0
                    text: "Health " + Math.round(card.health) + "%"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: panel.s(12)
                    color: ThemeBackend.subtext0
                }
            }
        }

        // saver / balanced / performance
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: panel.s(34)
            radius: height / 2
            color: ThemeBackend.surface1

            readonly property var names: PowerProfiles.hasPerformanceProfile ? ["Saver", "Balanced", "Performance"] : ["Saver", "Balanced"]
            readonly property real segW: width / names.length

            Rectangle {
                y: 3; height: parent.height - 6
                width: parent.segW - 6
                x: 3 + Math.min(card.profileIndex, parent.names.length - 1) * parent.segW
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
                        font.pixelSize: panel.s(12)
                        font.weight: Font.DemiBold
                        color: card.profileIndex === index ? ThemeBackend.crust : ThemeBackend.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = index === 0 ? PowerProfile.PowerSaver : (index === 1 ? PowerProfile.Balanced : PowerProfile.Performance)
                    }
                }
            }
        }
    }
}
