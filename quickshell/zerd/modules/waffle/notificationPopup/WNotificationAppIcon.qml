import QtQuick
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root

    property string icon: ""
    property real implicitSize: 16
    // Fallback (no resolvable app icon) reads as a bare, colorless glyph
    // floating with nothing around it - give it a soft chip so it looks
    // like a designed badge instead of a missing asset.
    readonly property bool isFallback: !icon
    implicitWidth: isFallback ? implicitSize * 1.3 : implicitSize
    implicitHeight: implicitWidth
    // Hard clip to the intended icon slot - real apps (Discord, Claude
    // Code...) commonly send a raw file path rather than an icon-theme
    // name as their app_icon, and Kirigami.Icon doesn't reliably constrain
    // that to implicitSize on its own, letting a full-resolution image
    // overflow past this small badge and swallow the rest of the card.
    clip: true

    Rectangle {
        anchors.fill: parent
        visible: root.isFallback
        // Squircle, not a circle - matches DockAppIcon's rounded-square
        // tile convention in the side dock (WSideDockContent.qml) instead
        // of the plain circular badge this used to be.
        radius: width * 0.28
        antialiasing: true
        color: Looks.colors.bg2
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        implicitWidth: root.implicitSize * (root.isFallback ? 0.75 : 1.0)
        implicitHeight: implicitWidth

        source: root.icon || fallback
        fallback: `${Looks.iconsPath}/apps.svg`
        roundToIconSize: true
        isMask: root.isFallback
        color: Looks.colors.subfg
    }
}
