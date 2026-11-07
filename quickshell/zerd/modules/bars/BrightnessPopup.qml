import QtQuick
import qs.services

// Screen brightness, capped so the panel never goes fully dark or the top step.
Column {
    id: root

    property var screen: null
    readonly property var mon: Brightness.getMonitorForScreen(root.screen) ?? Brightness.monitors[0]
    spacing: 10

    BarSlider {
        width: 300
        icon: "brightness_6"
        value: root.mon?.brightness ?? 0
        step: 0.05
        onMoved: v => root.mon?.setBrightness(Math.max(0.05, Math.min(0.99, v)))
    }
    Row {
        spacing: 8
        Repeater {
            model: [0.1, 0.25, 0.5, 0.75, 0.99]
            delegate: BarButton {
                id: chip
                required property real modelData
                readonly property bool on: Math.abs((root.mon?.brightness ?? 0) - modelData) < 0.04
                width: 56; height: 30; radius: pressed ? BarStyle.radiusSmall : 15
                tone: "tonal"; toggled: on
                onTapped: root.mon?.setBrightness(chip.modelData)
                BarText { anchors.centerIn: parent; text: Math.round(chip.modelData * 100) + "%"; font.pixelSize: 12; color: chip.ink }
            }
        }
    }
}
