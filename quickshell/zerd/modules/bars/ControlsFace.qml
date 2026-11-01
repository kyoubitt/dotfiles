import QtQuick
import qs.modules.dock2

// Brightness, volume and do-not-disturb rings (and Wi-Fi/Bluetooth if listed).
Item {
    id: root

    property bool vertical: false
    property var screen: null
    property var controls: []
    property int thickness: 34
    visible: controls.length > 0
    implicitWidth: vertical ? thickness : row.implicitWidth
    implicitHeight: vertical ? col.implicitHeight : thickness

    DockControls {
        id: row
        visible: !root.vertical
        screen: root.screen
        controls: root.controls
        size: Math.min(34, root.thickness)
        spacing: 6
        y: Math.round((root.thickness - height) / 2)
    }
    Column {
        id: col
        visible: root.vertical
        x: Math.round((root.thickness - width) / 2)
        spacing: 6
        Repeater {
            model: root.vertical ? root.controls : []
            delegate: DockControls {
                required property string modelData
                screen: root.screen
                controls: [modelData]
                size: Math.min(34, root.thickness)
            }
        }
    }
}
