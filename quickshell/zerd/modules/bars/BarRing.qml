import QtQuick

// A ring gauge with an icon and a value in the middle.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property string text: ""
    property color tint: BarStyle.accent
    property int diameter: 64
    implicitWidth: diameter
    implicitHeight: diameter

    Canvas {
        anchors.fill: parent
        property real v: root.value
        property color col: root.tint
        onVChanged: requestPaint()
        onColChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset()
            const r = width / 2 - 4
            c.lineWidth = 4; c.lineCap = "round"
            c.strokeStyle = Qt.rgba(BarStyle.subtext.r, BarStyle.subtext.g, BarStyle.subtext.b, 0.22)
            c.beginPath(); c.arc(width / 2, height / 2, r, 0, 2 * Math.PI); c.stroke()
            c.strokeStyle = col
            c.beginPath()
            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, Math.min(1, v)))
            c.stroke()
        }
    }
    BarIcon { anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(root.height / 2 - 17); size: 16; name: root.icon; color: BarStyle.subtext }
    BarText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height / 2 - 1)
        text: root.text
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
