pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.services

// Floating vertical bar on the left edge: workspaces on top, status in the
// middle, clock and power at the bottom.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        readonly property var options: Config.options?.bars?.side ?? ({})
        readonly property int barWidth: options.width ?? 44
        readonly property int margin: options.margin ?? 8

        screen: modelData
        color: "transparent"
        visible: !NiriService.inOverview && !GlobalStates.screenLocked
        anchors { top: true; bottom: true; left: true }
        implicitWidth: barWidth + 2 * margin
        exclusionMode: (options.reserve ?? false) ? ExclusionMode.Auto : ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:zerd-bar-side"
        WlrLayershell.layer: WlrLayer.Top

        mask: Region {
            Region { item: top }
            Region { item: middle }
            Region { item: bottom }
        }

        Column {
            id: top
            anchors.top: parent.top
            anchors.topMargin: win.margin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: BarStyle.gap
            WorkspacesFace { vertical: true; thickness: win.barWidth; output: win.screen?.name ?? "" }
            MediaFace { vertical: true; thickness: win.barWidth }
        }
        Column {
            id: middle
            anchors.centerIn: parent
            spacing: BarStyle.gap
            WeatherFace { vertical: true; thickness: win.barWidth }
            SysMonFace { vertical: true; thickness: win.barWidth }
        }
        Column {
            id: bottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.margin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: BarStyle.gap
            ControlsFace { vertical: true; thickness: win.barWidth; screen: win.screen; controls: win.options.controls ?? [] }
            VolumeFace { vertical: true; thickness: win.barWidth }
            NetFace { vertical: true; thickness: win.barWidth }
            BatteryFace { vertical: true; thickness: win.barWidth }
            TrayFace { vertical: true; thickness: win.barWidth; window: win }
            ClockFace { vertical: true; thickness: win.barWidth }
            PowerFace { vertical: true; thickness: win.barWidth }
        }
    }
}
