pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText: ""
    property var urgency: NotificationUrgency.Normal
    readonly property bool critical: {
        const value = button.urgency
        if (value === undefined || value === null)
            return false
        return value === NotificationUrgency.Critical
            || String(value).toLowerCase() === "critical"
    }

    implicitHeight: false ? Appearance.regalia.controlHeight : 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: false ? Appearance.regalia.controlRadius
        : false ? Appearance.zzz.controlRadius
        : false ? Appearance.angel.roundingSmall
        : false ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: false
        ? (button.critical ? Appearance.colors.colErrorContainer : Appearance.editorial.field)
        : false
        ? (button.critical ? Appearance.regalia.signalPlate : Appearance.regalia.controlPlate)
        : false
        ? (button.critical ? Appearance.zzz.secondary : Appearance.zzz.paperAlt)
        : button.critical
        ? Appearance.colors.colSecondaryContainer
        : false ? Appearance.angel.colGlassCard
        : false ? Appearance.inir.colLayer3
        : false ? "transparent"
        : Appearance.colors.colLayer4
    colBackgroundHover: false
        ? (button.critical ? Appearance.colors.colErrorContainerHover : Appearance.colors.colPrimaryContainerHover)
        : false
        ? (button.critical ? Appearance.regalia.signalPlateHover : Appearance.regalia.controlPlateHover)
        : false
        ? (button.critical
            ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colLayer2Hover)
        : button.critical
        ? Appearance.colors.colSecondaryContainerHover
        : false ? Appearance.angel.colGlassCardHover
        : false ? Appearance.inir.colLayer3Hover
        : false ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer4Hover
    colRipple: false
        ? (button.critical ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimaryContainerActive)
        : false
        ? (button.critical ? Appearance.regalia.signalPlateHover : Appearance.regalia.controlPlateActive)
        : false
        ? (button.critical
            ? Appearance.colors.colSecondaryContainerActive
            : Appearance.colors.colLayer2Active)
        : button.critical
        ? Appearance.colors.colSecondaryContainerActive
        : false ? Appearance.angel.colGlassCardActive
        : false ? Appearance.inir.colLayer3Active
        : false ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer4Active

    contentItem: StyledText {
        font.family: Appearance.font.family.monospace
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        font.weight: false ? Font.Medium : Font.Normal
        color: false
            ? (button.critical ? Appearance.colors.colOnErrorContainer : Appearance.editorial.fieldInk)
            : false
            ? (button.critical ? Appearance.regalia.signalPlateInk : Appearance.regalia.onColor)
            : false
            ? (button.critical ? Appearance.zzz.onSecondary : Appearance.zzz.ink)
            : button.critical
                ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
