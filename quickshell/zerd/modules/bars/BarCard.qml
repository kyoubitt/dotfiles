import QtQuick

// A card on a panel: the second surface layer, iNiR's card corner, a hairline edge. Optional title row on top.
Rectangle {
    id: root

    property string title: ""
    default property alias content: body.data
    property real pad: 12
    implicitHeight: (title.length > 0 ? 30 : 0) + body.childrenRect.height + 2 * pad
    radius: BarStyle.radiusMedium
    color: BarStyle.card
    border.width: 1
    border.color: BarStyle.edge

    BarText { visible: root.title.length > 0; x: root.pad + 2; y: root.pad - 2; text: root.title; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.subtext }
    Item {
        id: body
        x: root.pad; y: root.pad + (root.title.length > 0 ? 24 : 0)
        width: root.width - 2 * root.pad
        height: childrenRect.height
    }
}
