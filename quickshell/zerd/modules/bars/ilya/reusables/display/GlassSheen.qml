import QtQuick
import QtQuick.Effects
import qs.modules.common as Common
import "../../"

// Frosted glass for a card (bars.liquidGlass): the wallpaper behind it, blurred, a 1 px highlight along the top edge
// and a soft glow just inside the border. Put it as the first child of the card; it draws nothing while the switch is
// off. The blur is built only while the card is shown.
Item {
    id: sheen

    property real radius: parent && parent.radius !== undefined ? parent.radius : ThemeBackend.borderRadius
    property bool blurred: true
    readonly property bool on: ThemeBackend.liquidGlass && sheen.visibleInWindow
    readonly property bool visibleInWindow: sheen.window !== null && sheen.width > 0

    anchors.fill: parent
    z: -1
    visible: ThemeBackend.liquidGlass

    readonly property string wall: Common.Config.options?.background?.wallpaperPath ?? ""
    property real offX: 0
    property real offY: 0
    function place() {
        if (!sheen.window) return;
        const p = sheen.mapToItem(null, 0, 0);
        offX = p.x; offY = p.y;
    }
    onWidthChanged: place()
    onVisibleChanged: place()
    Component.onCompleted: place()

    // the blurred wallpaper, only while there is a wallpaper and the card is up
    Loader {
        anchors.fill: parent
        active: sheen.on && sheen.blurred && sheen.wall !== "" && sheen.window !== null
        sourceComponent: Item {
            Image {
                id: wp
                visible: false
                x: -sheen.offX
                y: -sheen.offY
                width: sheen.window ? sheen.window.width : 0
                height: sheen.window ? sheen.window.height : 0
                source: sheen.wall.startsWith("/") ? "file://" + sheen.wall : sheen.wall
                sourceSize: Qt.size(960, 540)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            ShaderEffectSource {
                id: crop
                visible: false
                sourceItem: wp
                sourceRect: Qt.rect(sheen.offX, sheen.offY, sheen.width, sheen.height)
                live: false
                recursive: false
            }
            Rectangle { id: mask; anchors.fill: parent; radius: sheen.radius; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: parent
                source: crop
                blurEnabled: true
                blur: 1.0
                blurMax: 40
                saturation: 0.25
                maskEnabled: true
                maskSource: mask
            }
        }
    }

    // soft glow inside the border
    Rectangle {
        anchors.fill: parent
        radius: sheen.radius
        color: "transparent"
        border.width: 6
        border.color: Qt.rgba(1, 1, 1, 0.035)
    }
    // 1 px highlight along the top edge
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: sheen.radius * 0.6; rightMargin: sheen.radius * 0.6 }
        height: 1
        color: Qt.rgba(1, 1, 1, 0.16)
    }
}
