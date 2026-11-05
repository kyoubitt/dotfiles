import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

GroupButton {
    id: button
    property string buttonIcon: ""
    property string buttonText: ""

    baseHeight: 36
    baseWidth: content.implicitWidth + 46
    clickedWidth: baseWidth + 6

    buttonRadius: false ? Appearance.zzz.controlRadius
        : false ? Appearance.angel.roundingSmall
        : false ? Appearance.inir.roundingSmall
        : false ? Appearance.rounding.small : baseHeight / 2
    buttonRadiusPressed: false ? Appearance.zzz.cornerRadius
        : false ? Appearance.angel.roundingSmall
        : false ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: false ? "transparent"
        : false ? Appearance.angel.colGlassCard
        : false ? Appearance.inir.colLayer2
        : false ? Appearance.editorial.layer(2)
        : false ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: false ? Appearance.zzz.chrome
        : false ? Appearance.angel.colGlassCardHover
        : false ? Appearance.inir.colLayer2Hover
        : false ? Appearance.editorial.field
        : false ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer2Hover
    colBackgroundActive: false ? Appearance.zzz.sticker
        : false ? Appearance.angel.colGlassCardActive
        : false ? Appearance.inir.colLayer2Active
        : false ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
    property color colText: false
        ? (toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
        : false
        ? (toggled ? Appearance.inir.colOnPrimaryContainer : Appearance.inir.colText)
        : false
        ? (toggled ? Appearance.editorial.fieldInk : Appearance.editorial.ink)
        : (toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1)

    contentItem: Item {
        id: content
        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight
        RowLayout {
            id: contentRowLayout
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                visible: buttonIcon !== ""
                text: buttonIcon
                iconSize: Appearance.font.pixelSize.huge
                color: button.colText
            }
            StyledText {
        font.family: Appearance.font.family.monospace
                visible: buttonText !== ""
                text: buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                color: button.colText
            }
        }
    }

}
