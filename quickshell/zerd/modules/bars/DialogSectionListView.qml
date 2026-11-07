import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledListView {
    Layout.fillWidth: true
    Layout.topMargin: -22
    Layout.bottomMargin: -16
    Layout.leftMargin: -Appearance.rounding.large
    Layout.rightMargin: -Appearance.rounding.large
    topMargin: 12
    bottomMargin: 12
    leftMargin: 20
    rightMargin: 20

    clip: true
    spacing: 4
    animateAppearance: false
}
