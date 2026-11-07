import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: statusItem
    property string icon
    property string statusText
    property string description
    hoverEnabled: true
    implicitHeight: statusItemRowLayout.implicitHeight
    implicitWidth: statusItemRowLayout.implicitWidth

    RowLayout {
        id: statusItemRowLayout
        spacing: 0
        MaterialSymbol {
            text: statusItem.icon
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.colors.colSubtext
        }
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.small
            text: statusItem.statusText
            color: Appearance.colors.colSubtext
            animateChange: true
        }
    }

    StyledToolTip {
        text: statusItem.description
        extraVisibleCondition: false
        alternativeVisibleCondition: statusItem.containsMouse
    }
}
