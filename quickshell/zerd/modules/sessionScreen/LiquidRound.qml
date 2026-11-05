import QtQuick
import qs.modules.bars

// A round button that is liquid too: resting on it raises the liquid, a click fires at once.
Item {
    id: lr
    required property string icon
    property bool big: false
    signal activated()
    implicitWidth: big ? 52 : 44; implicitHeight: 44
    width: implicitWidth; height: implicitHeight
    property real jar: lrMa.containsMouse ? 0.5 : 0
    Behavior on jar { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Rectangle {
        id: lrBody
        anchors.fill: parent
        radius: lrMa.containsMouse ? 16 : height / 2
        Behavior on radius { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutCubic } }
        color: BarStyle.cardHigh
        clip: true
        scale: lrMa.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutBack } }
        ShaderEffect {
            anchors.fill: parent
            visible: lr.jar > 0.001
            property real radius: lrBody.radius
            property real fillLevel: lr.jar
            property real waveAmp: Math.min(5, lrBody.height * lr.jar) * Math.sin(lr.jar * Math.PI)
            property vector2d itemSize: Qt.vector2d(width, height)
            property real phase: 0
            property real vertical: 1
            property color color1: Qt.darker(BarStyle.accent, 1.1)
            property color color2: BarStyle.accent
            property vector4d params: Qt.vector4d(1, 0, 0, 0)
            fragmentShader: Qt.resolvedUrl("fluid_wave.frag.qsb")
            NumberAnimation on phase { running: lr.jar > 0 && lr.jar < 1; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 800 }
        }
        BarIcon { anchors.centerIn: parent; name: lr.icon; size: lr.big ? 26 : 22; color: BarStyle.text }
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * lr.jar; clip: true
            BarIcon { x: Math.round((lrBody.width - width) / 2); y: Math.round((lrBody.height - height) / 2) - (lrBody.height - parent.height); name: lr.icon; size: lr.big ? 26 : 22; color: BarStyle.onAccent }
        }
    }
    MouseArea { id: lrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lr.activated() }
}
