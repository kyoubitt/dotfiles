import QtQuick

// Shows a dialog over the panel while `shown` is true and unloads it after it has faded out.
Loader {
    id: root
    property bool shown: false
    signal dismissed()
    anchors.fill: parent

    active: shown
    onActiveChanged: {
        if (active && item) {
            item.show = true
            item.forceActiveFocus()
        }
    }
    onLoaded: {
        item.show = true
        item.forceActiveFocus()
    }
    Connections {
        target: root.item
        function onDismiss() {
            root.item.show = false
            root.dismissed()
        }
        function onVisibleChanged() {
            if (!root.item.visible && !root.shown) root.active = false
        }
    }
}
