import qs.modules.common
import QtQuick

SequentialAnimation {
    id: switchAnim
    property bool down: false
    required property Item tabStack
    required property string nextSource

    ParallelAnimation {
        PropertyAnimation {
            target: switchAnim.tabStack
            properties: "opacity"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        PropertyAnimation {
            target: switchAnim.tabStack.anchors
            properties: "topMargin"
            to: 10 * (switchAnim.down ? -1 : 1)
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    PropertyAction {
        target: switchAnim.tabStack
        property: "source"
        value: switchAnim.nextSource
    }
    ParallelAnimation {
        PropertyAnimation {
            target: switchAnim.tabStack.anchors
            properties: "topMargin"
            from: 10 * -(switchAnim.down ? -1 : 1)
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        PropertyAnimation {
            target: switchAnim.tabStack
            properties: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }
}
