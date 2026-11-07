import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

StyledSlider {

    id: quickSlider
    required property string materialSymbol
    property string secondaryMaterialSymbol
    configuration: StyledSlider.Configuration.M
    stopIndicatorValues: []
    dividerValues: secondaryMaterialSymbol.length > 0 ? [secondaryIcon.iconLocation] : []

    MaterialSymbol {
        id: icon
        property bool nearFull: quickSlider.value >= 0.9
        anchors {
            verticalCenter: quickSlider.verticalCenter
            right: nearFull ? quickSlider.handle.right : quickSlider.right
            rightMargin: nearFull ? 14 : 8
        }
        iconSize: 20
        color: nearFull ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        text: quickSlider.materialSymbol

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on anchors.rightMargin {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    MaterialSymbol {
        id: secondaryIcon
        visible: secondaryMaterialSymbol.length > 0
        property real iconLocation: 0.3
        property bool nearIcon: iconLocation - quickSlider.value <= 0.1 && iconLocation - quickSlider.value > (quickSlider.handleWidth + 8 - 14) / quickSlider.effectiveDraggingWidth
        anchors {
            verticalCenter: quickSlider.verticalCenter
            right: nearIcon ? quickSlider.handle.right : quickSlider.right
            rightMargin: nearIcon ? 14 : (1 - iconLocation) * quickSlider.effectiveDraggingWidth + quickSlider.rightPadding + 8
        }
        iconSize: 20
        color: quickSlider.value >= iconLocation - 0.1 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        text: secondaryMaterialSymbol

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
