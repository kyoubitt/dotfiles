import QtQuick
import qs.services

// Title of the focused window.
BarPill {
    id: root

    property int maxTextWidth: 260
    readonly property string title: NiriService.activeWindow?.title ?? ""
    visible: title.length > 0 && !vertical

    BarText {
        text: root.title
        elide: Text.ElideRight
        width: 2 * Math.ceil(Math.min(implicitWidth, root.maxTextWidth) / 2)
    }
}
