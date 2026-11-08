import QtQuick

// The slider every bar popup shares: a thick rounded track that fills to the value, a round handle that grows under the
// pointer, and the track thickening while you drag. Click anywhere on it, drag, or scroll.
Item {
    id: root
    property real value: 0                    // 0..100
    property color tone: ThemeBackend.blue
    property bool muted: false
    property real trackHeight: 12
    signal moved(int percent)

    implicitHeight: 28

    readonly property bool active: ma.pressed
    // while dragging the handle follows the pointer exactly; otherwise it glides to the value
    property real shown: value
    Behavior on shown { enabled: !root.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    readonly property real frac: Math.max(0, Math.min(1, shown / 100))
    readonly property real thick: root.trackHeight + (root.active ? 4 : (ma.containsMouse ? 2 : 0))
    Behavior on thick { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: root.thick; radius: height / 2
        color: Qt.alpha(ThemeBackend.text, 0.10)
        Rectangle {
            width: Math.max(parent.height, parent.width * root.frac); height: parent.height; radius: height / 2
            color: root.muted ? ThemeBackend.surface2 : root.tone
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    Rectangle {
        id: handle
        width: root.active ? 24 : (ma.containsMouse ? 22 : 20); height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.frac
        color: root.muted ? ThemeBackend.overlay0 : Qt.lighter(root.tone, 1.25)
        border.width: 3; border.color: ThemeBackend.card
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function setFrom(mx) {
            const f = Math.max(0, Math.min(1, (mx - handle.width / 2) / Math.max(1, root.width - handle.width)));
            root.shown = f * 100;
            root.moved(Math.round(f * 100));
        }
        onPressed: m => setFrom(m.x)
        onPositionChanged: m => { if (pressed) setFrom(m.x) }
        onWheel: w => {
            const v = Math.max(0, Math.min(100, Math.round(root.value) + (w.angleDelta.y > 0 ? 3 : -3)));
            root.moved(v);
        }
    }
}
