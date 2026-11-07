import QtQuick
import "../../../reusables"
import "../../../"
import "../../"

// CPU and memory as two short readouts; a click opens the system panel.
BarFaceBase {
    id: root

    property real targetLength: row.implicitWidth + 24
    property bool isFaceVisible: true

    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : 0

    Component.onCompleted: SysData.subscribe()
    Component.onDestruction: SysData.unsubscribe()

    component Stat: Row {
        property string symbol
        property string label
        property int value
        spacing: 5
        Text {
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            text: parent.symbol
            font.family: ThemeBackend.symbolFont
            font.variableAxes: ({ "wght": 600, "opsz": 20 })
            font.pixelSize: 18
            color: ThemeBackend.subtext0
        }
        Text {
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label + " " + parent.value + "%"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: parent.value >= 85 ? ThemeBackend.red : ThemeBackend.text
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Stat { symbol: "memory"; label: "CPU"; value: SysData.cpu }
        Stat { symbol: "developer_board"; label: "RAM"; value: SysData.ramPercent }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popups.toggle("system", root)
    }
}
