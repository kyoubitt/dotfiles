import QtQuick
import QtQuick.Layouts

// The header every bar popup shares: a round icon tile, a title with one grey line under it, and the main value on the right.
RowLayout {
    id: root
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property string value: ""
    property color tone: ThemeBackend.blue
    property color valueColor: ThemeBackend.text
    property alias extra: extraSlot.data
    signal tileClicked()
    signal tileWheel(int delta)

    Layout.fillWidth: true
    spacing: 14

    Rectangle {
        Layout.preferredWidth: 52; Layout.preferredHeight: 52
        radius: 16
        color: Qt.alpha(root.tone, tileMa.containsMouse ? 0.30 : 0.20)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            font.family: "Material Symbols Rounded"
            font.variableAxes: ({ "wght": 600, "opsz": 24, "FILL": 1 })
            font.pixelSize: 26
            color: root.tone
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tileClicked()
            onWheel: wheel => root.tileWheel(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: root.title
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily; font.pixelSize: 16; font.weight: Font.Bold
            renderType: Text.NativeRendering
        }
        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            visible: root.subtitle !== ""
            text: root.subtitle
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily; font.pixelSize: 12
            renderType: Text.NativeRendering
        }
    }

    Item { id: extraSlot; Layout.preferredWidth: childrenRect.width; Layout.preferredHeight: childrenRect.height }

    Text {
        visible: root.value !== ""
        text: root.value
        color: root.valueColor
        font.family: ThemeBackend.fontFamily; font.pixelSize: 26; font.weight: Font.Bold
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
    }
}
