import QtQuick
import qs.modules.bars

// The one row every setting uses (the shape of ilyamiro's SettingsRow, serpantinum, AGPL-3.0): a title, a hint that wraps to
// two lines, and the control on the right, or under the text when `stacked`. A clickable row lights up under the pointer and
// taps like its control. A row found by the search flashes.
Item {
    id: row

    property string title: ""
    property string hint: ""
    property string rowId: ""
    property bool stacked: false
    property bool clickable: false
    property bool divider: true
    property var registry: null              // where rows list themselves so the search can find them
    property string highlightId: ""
    default property alias control: slot.data
    signal tapped()

    readonly property real pad: 18
    readonly property real slotW: slot.childrenRect.width
    readonly property real slotH: slot.childrenRect.height
    readonly property real textW: stacked ? width - 2 * pad : Math.max(120, width - 2 * pad - slotW - 20)
    readonly property real textH: (title.length > 0 ? titleText.height : 0) + (hintText.visible ? hintText.height + (title.length > 0 ? 2 : 0) : 0)

    width: parent ? parent.width : 400
    height: stacked ? Math.round((textH > 0 ? textH + 26 : 12) + slotH + 14) : Math.round(Math.max(hint.length > 0 ? 64 : 54, textH + 24, slotH + 20))

    BarHoverFill { anchors { fill: parent; margins: 4 } hovered: row.clickable && hover.hovered; pressed: row.clickable && tap.pressed }
    Rectangle {
        id: flash
        anchors { fill: parent; margins: 4 }
        radius: BarStyle.radiusSmall
        color: BarStyle.accent
        opacity: 0
    }
    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: flash; property: "opacity"; to: 0.28; duration: 280; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1100 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InOutSine }
    }
    onHighlightIdChanged: if (rowId.length > 0 && highlightId === rowId) flashAnim.restart()

    Column {
        id: texts
        x: row.pad
        y: row.stacked ? 14 : Math.round((row.height - row.textH) / 2)
        width: row.textW
        spacing: 2
        BarText { id: titleText; visible: row.title.length > 0; width: parent.width; elide: Text.ElideRight; text: row.title }
        BarText {
            id: hintText
            visible: text.length > 0
            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            font.pixelSize: 12; color: BarStyle.subtext
            text: row.hint
        }
    }
    Item {
        id: slot
        x: row.stacked ? row.pad : row.width - row.pad - width
        y: row.stacked ? Math.round((row.textH > 0 ? 14 + row.textH + 12 : 12)) : Math.round((row.height - height) / 2)
        width: childrenRect.width; height: childrenRect.height
    }

    Rectangle {
        visible: row.divider
        anchors.bottom: parent.bottom
        x: row.pad; width: row.width - 2 * row.pad; height: 1
        color: BarStyle.border; opacity: 0.45
    }
    HoverHandler { id: hover; enabled: row.clickable; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: row.clickable; onTapped: row.tapped() }

    Component.onCompleted: if (registry && rowId.length > 0) registry[rowId] = row
    Component.onDestruction: if (registry && registry[rowId] === row) delete registry[rowId]
}
