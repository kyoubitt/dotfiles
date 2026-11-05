import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton { // Expand button
    id: root
    required property int count
    required property bool expanded
    property real fontSize: Appearance?.font.pixelSize.small ?? 12
    property real iconSize: Appearance?.font.pixelSize.normal ?? 16
    implicitHeight: fontSize + 4 * 2
    implicitWidth: Math.max(contentItem.implicitWidth + 5 * 2, 30)
    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: false

    buttonRadius: false ? Appearance.rounding.small : false ? Appearance.zzz.controlRadius : Appearance.rounding.full
    colBackground: false
        ? (expanded ? Appearance.zzz.sticker : Appearance.zzz.paperAlt)
        : false
        ? Appearance.angel.colGlassCard
        : false 
        ? Appearance.inir.colLayer2Hover
        : false 
        ? Appearance.aurora.colSubSurface
        : ColorUtils.mix(Appearance?.colors.colLayer2, Appearance?.colors.colLayer2Hover, 0.5)
    colBackgroundHover: false
        ? (expanded ? ColorUtils.applyAlpha(Appearance.zzz.sticker, 0.88) : ColorUtils.mix(Appearance.zzz.paperAlt, Appearance.zzz.signal, 0.92))
        : false
        ? Appearance.angel.colGlassCardHover
        : false 
        ? Appearance.inir.colLayer3Hover
        : false 
        ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer2Hover
    colRipple: false
        ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
        : false
        ? Appearance.angel.colGlassCardActive
        : false 
        ? Appearance.inir.colLayer3Active
        : false 
        ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: contentRow.implicitWidth
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 3
            StyledText {
        font.family: Appearance.font.family.monospace
                Layout.leftMargin: 4
                visible: root.count > 1
                text: root.count
                font.pixelSize: root.fontSize
                color: false
                    ? (expanded ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : Appearance.colors.colOnLayer2
            }
            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: root.iconSize
                color: false
                    ? (expanded ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : Appearance.colors.colOnLayer2
                rotation: expanded ? 180 : 0
                Behavior on rotation {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }
}
