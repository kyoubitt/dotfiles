pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()

    // Position from shared notifications config
    readonly property string position: Config.options?.notifications?.position ?? "bottomRight"
    readonly property bool isCenter: position === "center"
    readonly property bool isTopCenter: position === "topCenter"
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isLeft: position.endsWith("Left")
    readonly property int edgeMargin: Config.options?.notifications?.edgeMargin ?? 4
    // niri already keeps anchored-top layer-shell surfaces clear of
    // customBar's own reserved 44px exclusive zone automatically - this is
    // just a bit of extra breathing room on top of that, not the full gap.
    readonly property int barClearance: 10

    PanelWindow {
        id: panelWindow
        // Hide during GameMode to avoid input interference
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !GlobalStates.waffleNotificationCenterOpen && !GameMode.active

        screen: CompositorService.isNiri
            ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0]
            : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "quickshell:wNotificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0
        
        // Only capture input on actual notification area
        mask: Region {
            item: listview
        }

        // No anchor edges set = unanchored layer-shell surface, which niri
        // centers on screen by default - the wlr-layer-shell protocol doesn't
        // define a "center" anchor, this is the standard way to get one.
        // Anchoring only "top" (no left/right) centers horizontally while
        // staying pinned to the top edge, same idea for "topCenter".
        anchors {
            top: !root.isCenter && (root.isTop || root.isTopCenter)
            bottom: !root.isCenter && !root.isTopCenter && !root.isTop
            left: !root.isCenter && !root.isTopCenter && root.isLeft
            right: !root.isCenter && !root.isTopCenter && !root.isLeft
        }

        margins {
            top: (root.isTop || root.isTopCenter) ? root.barClearance : root.edgeMargin
            bottom: root.edgeMargin
            left: root.edgeMargin
            right: root.edgeMargin
        }

        color: "transparent"
        implicitWidth: 380
        implicitHeight: Math.min(listview.contentHeight + 16, (screen?.height ?? 800) * 0.7)

        WNotificationListView {
            id: listview
            anchors {
                fill: parent
                margins: 8
            }
        }
    }
}
