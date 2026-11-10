import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.services
import qs.modules.bars
import qs.modules.iris.host
import qs.modules.iris.widgets
import qs.modules.iris.style
import qs.modules.background.widgets.clock
import qs.modules.background.widgets.shape
import qs.modules.background.widgets.visualizer

// Floating desktop cards, drawn inside the wallpaper window so they sit under
// every app. Each card is placed from its config: a corner anchor plus pixel
// margins (Config.options.desktopWidgets.<name>).
Item {
    id: root

    // The whole layer steps aside for the overview and when switched off.
    visible: !DesktopWidgets.hidden && !NiriService.inOverview

    component Placed: Loader {
        id: placed
        required property string name
        readonly property var cfg: Config.options?.desktopWidgets?.[name] ?? ({})
        readonly property string anchorName: cfg.anchor ?? "topLeft"
        readonly property real cs: WidgetRegistry.visualScale(name)
        scale: cs
        transformOrigin: Item.TopLeft

        sourceComponent: Component {
            CardView {
                name: placed.name; screenRef: root.screenRef
                // right-click a card: the widget menu (edit, remove)
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: point => { BarState.sidebar = ""; GlobalStates.barPopup = { kind: "desktopmenu", widget: placed.name, x: Math.round(point.scenePosition.x), y: Math.round(point.scenePosition.y), tab: "" } }
                }
            }
        }
        active: root.visible && (cfg.enable ?? false)
        x: Math.round(anchorName.endsWith("Right") ? root.width - width * cs - (cfg.mx ?? 0)
            : anchorName.endsWith("Left") ? (cfg.mx ?? 0) : (root.width - width * cs) / 2)
        y: Math.round(anchorName.startsWith("bottom") ? root.height - height * cs - (cfg.my ?? 0)
            : anchorName.startsWith("top") ? (cfg.my ?? 0) : (root.height - height * cs) / 2)
    }

    readonly property var screenRef: QsWindow.window?.screen ?? null

    // iNiR's iRiS cards (modules/iris), each inside a small host that answers
    // the settings they read.
    // Clocks and shapes from iNiR's desktop-widget set (modules/background/widgets).
    // Notes: the iRiS card is just the frame; the text box sits on top of it.
    Repeater {
        model: DesktopWidgets.names
        delegate: Placed { required property string modelData; name: modelData }
    }
}
