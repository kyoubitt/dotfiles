import QtQuick
import "reusables"

// A tall capsule like the ones on the power menu: outlined, an icon and a name inside, and liquid rising from the
// bottom to the level. The icon and name turn dark where the liquid is. Used by the battery and system popups.
Item {
    id: root
    property string icon: ""
    property string value: ""
    property string caption: ""
    property real level: 0                    // 0..1
    property color tone: ThemeBackend.blue
    property bool lit: hover.containsMouse
    property bool interactive: false          // press and drag up or down to set the level, wheel steps it
    signal moved(real fraction)
    signal stepped(int direction)

    implicitWidth: 112
    implicitHeight: 160

    property real shown: 0
    Behavior on shown { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    onLevelChanged: shown = Math.max(0, Math.min(1, level))
    Component.onCompleted: shown = Math.max(0, Math.min(1, level))

    Rectangle {
        id: capsule
        anchors.fill: parent
        radius: 44
        color: Qt.alpha(ThemeBackend.surface0, 0.35)
        border.width: 1.5
        border.color: Qt.alpha(ThemeBackend.text, root.lit ? 0.40 : 0.16)
        Behavior on border.color { ColorAnimation { duration: 150 } }
        clip: true
        scale: root.lit ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

        FluidWave {
            id: wave
            anchors.fill: parent
            property real wavePhase: 0
            NumberAnimation on wavePhase { running: root.visible && root.shown > 0.01 && root.shown < 0.99; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 2400 }
            radius: capsule.radius
            fillLevel: root.shown
            waveAmp: fillLevel < 0.99 ? Math.min(7, capsule.height * fillLevel, capsule.height * (1 - fillLevel)) * Math.sin(fillLevel * Math.PI) : 0
            phase: wavePhase
            vertical: 1.0
            color1: Qt.darker(root.tone, 1.1)
            color2: root.tone
            visible: root.shown > 0.01
        }

        Item {
            anchors.fill: parent
            Text {
                x: Math.round((parent.width - width) / 2); y: 30
                text: root.icon
                font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 500, "opsz": 40, "FILL": 0 })
                font.pixelSize: 42; color: ThemeBackend.text
                renderType: Text.NativeRendering
            }
            Text {
                y: 90; width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: root.value
                font.family: ThemeBackend.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.features: { "tnum": 1 }
                color: ThemeBackend.text
                renderType: Text.NativeRendering
            }
            Text {
                y: 115; width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: root.caption
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12
                color: ThemeBackend.text; opacity: 0.75
                renderType: Text.NativeRendering
            }
        }
        // the same, dark, only where the liquid is
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * root.shown
            clip: true
            Item {
                x: 0; y: -(capsule.height - parent.height); width: capsule.width; height: capsule.height
                Text {
                    x: Math.round((parent.width - width) / 2); y: 30
                    text: root.icon
                    font.family: "Material Symbols Rounded"; font.variableAxes: ({ "wght": 500, "opsz": 40, "FILL": 1 })
                    font.pixelSize: 42; color: ThemeBackend.crust
                    renderType: Text.NativeRendering
                }
                Text {
                    y: 90; width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: root.value
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.features: { "tnum": 1 }
                    color: ThemeBackend.crust
                    renderType: Text.NativeRendering
                }
                Text {
                    y: 115; width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: root.caption
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12
                    color: ThemeBackend.crust; opacity: 0.8
                    renderType: Text.NativeRendering
                }
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: m => { if (root.interactive) root.moved(Math.max(0, Math.min(1, 1 - m.y / height))) }
        onPositionChanged: m => { if (root.interactive && pressed) root.moved(Math.max(0, Math.min(1, 1 - m.y / height))) }
        onWheel: w => { if (root.interactive) root.stepped(w.angleDelta.y > 0 ? 1 : -1) }
    }
}
