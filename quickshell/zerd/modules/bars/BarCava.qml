import QtQuick
import qs.services
import qs.services.deferred

// A few cava bars. Subscribes to the shared cava process only while visible.
Item {
    id: root

    property int count: 10
    property bool vertical: false
    property int request: -1
    implicitWidth: vertical ? 18 : count * 4
    implicitHeight: vertical ? count * 4 : 18

    onVisibleChanged: {
        if (visible && request < 0) request = CavaService.subscribe(root.count)
        else if (!visible && request >= 0) { CavaService.unsubscribe(request); request = -1 }
    }
    Component.onCompleted: if (visible) request = CavaService.subscribe(root.count)
    Component.onDestruction: if (request >= 0) CavaService.unsubscribe(request)

    Repeater {
        model: root.count
        delegate: Rectangle {
            required property int index
            readonly property real level: Math.max(0.12, Math.min(1, (CavaService.points[index] ?? 0) / CavaService.normalizationCeiling))
            radius: 1.5
            color: BarStyle.accent
            width: root.vertical ? Math.round(18 * level) : 3
            height: root.vertical ? 3 : Math.round(18 * level)
            x: root.vertical ? 0 : index * 4
            y: root.vertical ? index * 4 : 18 - height
            Behavior on height { NumberAnimation { duration: 60 } }
            Behavior on width { NumberAnimation { duration: 60 } }
        }
    }
}
