pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// A second dock family next to the iRiS one: macOS, pill or panel style
// (`dock2.style`). One layer per output, click-through except the dock.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        readonly property var options: Config.options?.dock2 ?? ({})
        readonly property string style: Config.options?.dock?.kind ?? "macos"

        screen: modelData
        color: "transparent"
        visible: !NiriService.inOverview && !GlobalStates.screenLocked
        anchors { left: true; right: true; bottom: true }
        implicitHeight: bar.implicitHeight + (style === "panel" ? 0 : 20)
        exclusionMode: style === "panel" || (options.reserve ?? false) ? ExclusionMode.Auto : ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:zerd-dock2"
        WlrLayershell.layer: WlrLayer.Top

        mask: Region {
            Region { item: bar }
            Region { item: controlsRegion }
        }
        Item {
            id: controlsRegion
            x: bar.x + bar.width + 10
            y: bar.y
            width: (win.options.controls ?? []).length * 44
            height: bar.height
        }

        ClassicDockBar {
            id: bar
            style: win.style
            iconSize: win.options.iconSize ?? 44
            screen: win.screen
            controls: win.options.controls ?? []
            width: style === "panel" ? win.width : implicitWidth
            height: implicitHeight
            x: Math.round((win.width - width) / 2)
            y: win.height - height - (style === "panel" ? 0 : 10)
        }
    }
}
