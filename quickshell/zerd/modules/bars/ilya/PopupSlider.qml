import QtQuick
import qs.modules.bars

// The popups' slider is the shell's one slider (BarSlider): a thick rounded track that fills to the value with a handle
// at its end. The value here is 0..100 like the Audio service; the tone is the popup's accent.
Item {
    id: root
    property real value: 0                    // 0..100
    property color tone: BarStyle.accent
    property bool muted: false
    signal moved(int percent)

    implicitHeight: 28
    BarSlider {
        anchors.fill: parent
        trackHeight: 28
        step: 0.03
        tone: root.tone
        muted: root.muted
        value: root.value / 100
        onMoved: v => root.moved(Math.round(v * 100))
    }
}
