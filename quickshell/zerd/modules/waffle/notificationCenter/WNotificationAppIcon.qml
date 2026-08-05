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
    implicitWidth: isFallback ? implicitSize * 1.6 : implicitSize
    implicitHeight: implicitWidth

    Rectangle {
        anchors.fill: parent
        visible: root.isFallback
        radius: width / 2
        color: Looks.colors.bg2
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        implicitWidth: root.implicitSize * (root.isFallback ? 0.62 : 1.0)
        implicitHeight: implicitWidth

        source: root.icon || fallback
        fallback: `${Looks.iconsPath}/apps.svg`
        roundToIconSize: true
        isMask: root.isFallback
        color: Looks.colors.subfg
    }
}
