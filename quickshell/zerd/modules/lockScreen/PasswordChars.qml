pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

// One expressive shape per typed character. Each grows in with a springy
// overshoot and settles from the accent colour to the foreground colour.
// The row follows the newest character when the password outgrows the field.
Flickable {
    id: root

    required property int length

    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentWidth: dotsRow.implicitWidth
    contentX: Math.max(contentWidth - width, 0)
    Behavior on contentX {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Row {
        id: dotsRow
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 4
        }
        spacing: 10

        Repeater {
            model: root.length

            delegate: Item {
                id: charItem
                required property int index

                implicitWidth: 10
                implicitHeight: 10

                MaterialShape {
                    id: shape
                    anchors.centerIn: parent

                    readonly property list<var> charShapes: [
                        MaterialShape.Shape.Clover4Leaf,
                        MaterialShape.Shape.Arrow,
                        MaterialShape.Shape.Pill,
                        MaterialShape.Shape.SoftBurst,
                        MaterialShape.Shape.Diamond,
                        MaterialShape.Shape.ClamShell,
                        MaterialShape.Shape.Pentagon,
                    ]
                    shape: charShapes[charItem.index % charShapes.length]

                    color: SMColors.accent
                    implicitSize: 0
                    opacity: 0
                    scale: 0.5

                    Component.onCompleted: appear.start()

                    ParallelAnimation {
                        id: appear
                        NumberAnimation {
                            target: shape
                            property: "opacity"
                            to: 1
                            duration: 50
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: shape
                            property: "scale"
                            to: 1
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                        }
                        NumberAnimation {
                            target: shape
                            property: "implicitSize"
                            to: 18
                            duration: 350
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                        }
                        ColorAnimation {
                            target: shape
                            property: "color"
                            from: SMColors.accent
                            to: SMColors.fg
                            duration: 1000
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
