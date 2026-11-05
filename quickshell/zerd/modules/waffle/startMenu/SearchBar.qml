pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu
import qs.modules.bars

FooterRectangle {
    id: root

    property real horizontalPadding: 12
    property real verticalPadding: 4
    property bool searching: text.length > 0
    property alias searchInput: searchInput
    property alias text: searchInput.text
    implicitHeight: card.implicitHeight + verticalPadding * 2

    signal accepted()

    Component.onCompleted: forceFocus()
    function forceFocus() {
        searchInput.forceActiveFocus();
    }

    focus: true
    color: SMColors.bg

    Rectangle {
        id: card
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            verticalCenter: parent.verticalCenter
        }
        implicitHeight: content.implicitHeight + 24
        radius: height / 2
        antialiasing: true
        color: BarStyle.card
        border.width: 2
        border.color: searchInput.activeFocus ? SMColors.accent : "transparent"
        Behavior on border.color { ColorAnimation { duration: 120 } }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 11

            BarIcon {
                Layout.alignment: Qt.AlignVCenter
                name: "search"
                size: 22
                color: BarStyle.subtext
            }

            WTextInput {
                id: searchInput
                focus: true
                Layout.fillWidth: true
                color: SMColors.fg
                font.pixelSize: 18

                WText {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.6)
                    text: Translation.tr("Search for apps")
                    visible: searchInput.text.length === 0
                    font.pixelSize: 18
                }

                onAccepted: {
                    root.accepted();
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.NoButton
    }
}
