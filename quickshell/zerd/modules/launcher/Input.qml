import QtQuick
import qs.modules.common
import qs.modules.bars

// The launcher's search field: a pill with an icon, the text, a clear button. Keys the field does not use
// (arrows, Tab, Enter, Esc) reach the handlers set on this item by the launcher.
Item {
    id: root

    property color baseColor: BarStyle.card
    property real bgOpacity: 1
    property color accentColor: BarStyle.accent
    property color textColor: BarStyle.text
    property color subTextColor: BarStyle.subtext
    property color borderColor: BarStyle.border
    property real cornerRadius: 18
    property int fontPixelSize: 16
    property int charSpacing: 0
    property string placeholderText: ""
    property bool showClearButton: false
    property alias text: field.text
    readonly property bool hasFocus: field.activeFocus
    signal textEdited(string newText)
    signal cleared()

    function forceInputFocus(): void { field.forceActiveFocus() }
    function clear(): void { field.text = "" }
    onActiveFocusChanged: if (activeFocus) field.forceActiveFocus()

    implicitHeight: 44
    Rectangle {
        anchors.fill: parent
        radius: Math.min(root.cornerRadius, height / 2)
        color: root.baseColor
        opacity: root.bgOpacity
        border.width: 2
        border.color: field.activeFocus ? root.accentColor : "transparent"
        Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
    }
    BarIcon { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; color: root.subTextColor }
    TextInput {
        id: field
        x: 46
        width: parent.width - 46 - (root.showClearButton && text.length > 0 ? 46 : 16)
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        color: root.textColor
        selectionColor: root.accentColor
        selectedTextColor: BarStyle.onAccent
        font.family: Appearance.font.family.expressive
        font.pixelSize: Math.max(14, root.fontPixelSize)
        font.letterSpacing: root.charSpacing * 0.1
        renderType: Text.QtRendering
        clip: true
        Keys.forwardTo: [root]
        onTextEdited: root.textEdited(text)
        BarText {
            visible: field.text.length === 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: root.placeholderText
            color: root.subTextColor
            font.pixelSize: field.font.pixelSize
            elide: Text.ElideRight
        }
    }
    BarButton {
        visible: root.showClearButton && field.text.length > 0
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 15; tone: "plain"
        onTapped: { field.text = ""; root.cleared(); field.forceActiveFocus() }
        BarIcon { anchors.centerIn: parent; name: "close"; size: 16; color: parent.parent.ink }
    }
}
