import QtQuick
import qs.modules.bars

// A group of settings: a small heading and one card; the rows go in as children, stacked.
Item {
    id: group

    property string title: ""
    default property alias rows: col.data

    width: parent ? parent.width : 400
    height: (title.length > 0 ? 28 : 0) + col.height

    BarText {
        visible: group.title.length > 0
        x: 6; y: 0
        text: group.title
        font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.subtext
    }
    Rectangle {
        y: group.title.length > 0 ? 28 : 0
        width: group.width; height: col.height
        radius: BarStyle.radiusLarge
        color: BarStyle.card
        border.width: 1; border.color: BarStyle.edge
    }
    Column {
        id: col
        y: group.title.length > 0 ? 28 : 0
        width: group.width
    }
}
