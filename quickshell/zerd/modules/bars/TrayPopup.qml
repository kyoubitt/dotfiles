import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.services

// Every tray icon with its name. Left click activates, right click opens the app's menu, the eye keeps an icon out of
// the bar (it stays here).
Column {
    id: root

    property var window: null
    readonly property var hiddenIds: Config.options?.bars?.top?.trayHidden ?? []
    spacing: 8
    width: 320

    function setHidden(id: string, hide: bool): void {
        const list = root.hiddenIds.filter(x => x !== id)
        if (hide) list.push(id)
        Config.options.bars.top.trayHidden = list
    }

    BarText { text: "Tray"; font.weight: Font.DemiBold; font.pixelSize: 15 }
    BarText { visible: SystemTray.items.values.length === 0; text: "Nothing in the tray"; color: BarStyle.subtext }

    BarCard {
        visible: SystemTray.items.values.length > 0
        width: parent.width
        pad: 6
        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: SystemTray.items.values
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool hidden: root.hiddenIds.includes(modelData.id)
                    width: parent.width; height: 40
                    BarHoverFill { anchors.fill: parent; hovered: area.containsMouse; pressed: area.pressed }
                    IconImage { id: glyph; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; source: TrayService.getSafeIcon(row.modelData); mipmap: true; visible: status !== Image.Error && source.toString().length > 0 }
                    BarIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "apps"; size: 22; color: BarStyle.subtext; visible: !glyph.visible }
                    Column {
                        x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44 - 48
                        BarText { width: parent.width; text: row.modelData.tooltipTitle || row.modelData.title || row.modelData.id; elide: Text.ElideRight }
                        BarText {
                            visible: text.length > 0; width: parent.width; font.pixelSize: 11; color: BarStyle.subtext; elide: Text.ElideRight
                            text: row.hidden ? "Hidden from the bar" : (row.modelData.status === Status.Passive ? "Passive" : "")
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || row.modelData.onlyMenu) {
                                if (row.modelData.hasMenu) {
                                    const p = row.mapToItem(null, row.width / 2, 0)
                                    GlobalStates.barPopup = { kind: "traymenu", x: p.x, item: row.modelData.id }
                                }
                            } else if (mouse.button === Qt.MiddleButton) row.modelData.secondaryActivate()
                            else { row.modelData.activate(); GlobalStates.barPopup = null }
                        }
                    }
                    Item {
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30
                        BarHoverFill { anchors.fill: parent; radius: 15; hovered: eye.containsMouse; pressed: eye.pressed }
                        BarIcon { anchors.centerIn: parent; name: row.hidden ? "visibility_off" : "visibility"; size: 18; color: row.hidden ? BarStyle.subtext : BarStyle.text }
                        MouseArea { id: eye; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setHidden(row.modelData.id, !row.hidden) }
                    }
                }
            }
        }
    }
}
