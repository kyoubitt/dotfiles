import QtQuick
import qs.modules.common
import qs.modules.bars

// The Applications / Files / Emojis selector: a pill with a highlight that slides to the chosen tab.
Item {
    id: root
    property var options: []
    property int currentIndex: 0
    property real cornerRadius: 14
    property int fontPixelSize: 13
    property color baseColor: BarStyle.card
    property real bgOpacity: 1
    property color accentColor: BarStyle.accent
    property color textColor: BarStyle.text
    property color activeTextColor: BarStyle.onAccent
    signal valueChanged(int index, var value)
    signal toggled(int index)

    implicitHeight: 34
    Rectangle { anchors.fill: parent; radius: height / 2; color: root.baseColor; opacity: root.bgOpacity }
    Rectangle {
        id: hl
        readonly property real seg: (root.width - 6) / Math.max(1, root.options.length)
        x: 3 + root.currentIndex * seg; y: 3
        width: seg; height: root.height - 6
        radius: height / 2
        color: root.accentColor
        Behavior on x { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
    }
    Row {
        x: 3; y: 3
        Repeater {
            model: root.options
            delegate: Item {
                required property int index
                required property var modelData
                width: hl.seg; height: root.height - 6
                BarText {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: Math.max(13, root.fontPixelSize)
                    color: root.currentIndex === parent.index ? root.activeTextColor : root.textColor
                    Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.valueChanged(parent.index, parent.modelData); root.toggled(parent.index) }
                }
            }
        }
    }
}
