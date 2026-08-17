pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    Loader {
        id: loader
        required property var modelData

        readonly property var wDock: Config.options.waffles?.sideDock ?? {}
        readonly property string edge: wDock.edge ?? "side" // "side"/"right" | "left" (vertical) | "top" | "bottom"
        readonly property bool horizontal: edge === "top" || edge === "bottom"
        readonly property int thickness: wDock.thickness ?? 42
        readonly property bool autoHide: wDock.autoHide ?? false
        readonly property int autoHideDelayMs: wDock.autoHideDelayMs ?? 500

        // Two separate PanelWindow components rather than one with
        // ternary'd anchors/implicit sizing: Quickshell clamps/honors an
        // explicit implicitWidth (or implicitHeight) even on the axis
        // that's meant to stretch across both anchored edges, which
        // silences the anchor-driven stretch entirely. The fix is to never
        // bind that axis's implicit size at all, which a single dynamic
        // component can't do conditionally - so each orientation gets its
        // own component that only ever touches its own thickness axis.
        sourceComponent: horizontal ? horizontalPanel : verticalPanel

        Component {
            id: verticalPanel
            PanelWindow {
                id: panelRoot
                screen: loader.modelData
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell:wSideDock"
                anchors { top: true; bottom: true; right: loader.edge !== "left"; left: loader.edge === "left" }
                implicitWidth: loader.thickness
                // Auto-hide overlays instead of reserving space - a
                // permanent exclusiveZone would keep windows clear of a
                // dock that isn't there most of the time.
                // Reserves space only while actually shown. When autoHide
                // is off, revealed is permanently true, so this is just
                // loader.thickness always - identical to the pre-autoHide
                // behavior. When autoHide is on, this toggles live between
                // 0 and thickness, so niri reflows windows to make room for
                // the dock as it reveals rather than the dock overlaying
                // whatever's underneath it.
                exclusiveZone: panelRoot.revealed ? loader.thickness : 0
                // No manual top margin: niri already auto-positions any
                // top-anchored surface below other surfaces' exclusiveZone
                // (the top bar's, here), so a manual margins.top was
                // stacking on top of that automatic offset - the dock was
                // actually starting further down than intended, which was
                // the real "gap". Let niri's own exclusive-zone stacking do it.
                margins.top: 0
                margins.bottom: 0
                visible: loader.wDock.enable ?? true

                // Starts hidden when autoHide is on, so there's no
                // startup flash before the cursor ever reaches the edge.
                property bool revealed: !loader.autoHide

                // Same mask:Region{item:...} idiom as ToastManager/
                // WaffleNotificationPopup - restricts input (and hover
                // delivery) to a thin strip at the true screen edge while
                // hidden, so windows underneath stay fully clickable right
                // up to that strip. Not used at all when autoHide is off.
                // Always masked to contentHit (== full window) once
                // revealed or when autoHide is off, so this is a no-op
                // there; narrows to just the edge strip while hidden.
                // A `Region {...}` object literal can't live inside a JS
                // ternary (that's a declarative child-object slot, not an
                // expression) - only its `item` target is ternary'd.
                mask: Region {
                    item: (loader.autoHide && !panelRoot.revealed) ? edgeHit : contentHit
                }

                Item {
                    id: edgeHit
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: loader.edge === "left" ? parent.left : undefined
                        right: loader.edge !== "left" ? parent.right : undefined
                    }
                    width: 6
                }

                Item {
                    id: contentHit
                    anchors.fill: parent
                }

                Timer {
                    id: hideTimer
                    interval: loader.autoHideDelayMs
                    onTriggered: panelRoot.revealed = false
                }

                // acceptedButtons: NoButton so this overlay never eats a
                // click meant for a button inside WSideDockContent below it
                // (Qt still routes hover to it independently of that) or,
                // while hidden, for whatever window sits under the strip.
                // HoverHandler, not MouseArea: WSideDockContent's own
                // buttons (workspace dots, app icons, toggles) each have
                // their own hoverEnabled MouseArea, and QtQuick only
                // delivers hover to the topmost MouseArea at a point - a
                // MouseArea here would lose "hovered" the instant the
                // cursor reached any dock button (firing this exit early,
                // starting the hide countdown while still over the dock),
                // and never see the real leave when the cursor finally
                // moved off (that final leave would go to the button's own
                // MouseArea instead). HoverHandler is a passive observer
                // that isn't affected by children grabbing hover/clicks
                // underneath it, so it tracks "pointer anywhere in the
                // whole dock" correctly regardless of what's under it.
                HoverHandler {
                    id: revealHover
                    enabled: loader.autoHide
                    onHoveredChanged: {
                        if (revealHover.hovered) {
                            hideTimer.stop()
                            panelRoot.revealed = true
                        } else {
                            hideTimer.restart()
                        }
                    }
                }

                Item {
                    id: slideWrap
                    anchors.fill: parent
                    // Slides fully past the screen edge (not just to the
                    // panel's own boundary) when hidden, so no sliver of
                    // the dock's background renders while tucked away.
                    x: (!loader.autoHide || panelRoot.revealed) ? 0 : (loader.edge === "left" ? -loader.thickness : loader.thickness)
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    WSideDockContent {
                        anchors.fill: parent
                        screen: panelRoot.screen
                        horizontal: false
                        dockOnLeft: loader.edge === "left"
                        // Must match WTopBar's thickness - this is only for the
                        // blurred-wallpaper crop offset math, not positioning
                        // (niri handles that), but a mismatch here would make
                        // the crop discontinuous at the seam again.
                        floatMarginTop: 42
                    }
                }
            }
        }

        Component {
            id: horizontalPanel
            PanelWindow {
                id: panelRoot
                screen: loader.modelData
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell:wSideDock"
                anchors { left: true; right: true; top: loader.edge === "top"; bottom: loader.edge === "bottom" }
                implicitHeight: loader.thickness
                // Reserves space only while actually shown. When autoHide
                // is off, revealed is permanently true, so this is just
                // loader.thickness always - identical to the pre-autoHide
                // behavior. When autoHide is on, this toggles live between
                // 0 and thickness, so niri reflows windows to make room for
                // the dock as it reveals rather than the dock overlaying
                // whatever's underneath it.
                exclusiveZone: panelRoot.revealed ? loader.thickness : 0
                visible: loader.wDock.enable ?? true

                property bool revealed: !loader.autoHide

                // Always masked to contentHit (== full window) once
                // revealed or when autoHide is off, so this is a no-op
                // there; narrows to just the edge strip while hidden.
                // A `Region {...}` object literal can't live inside a JS
                // ternary (that's a declarative child-object slot, not an
                // expression) - only its `item` target is ternary'd.
                mask: Region {
                    item: (loader.autoHide && !panelRoot.revealed) ? edgeHit : contentHit
                }

                Item {
                    id: edgeHit
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: loader.edge === "top" ? parent.top : undefined
                        bottom: loader.edge !== "top" ? parent.bottom : undefined
                    }
                    height: 6
                }

                Item {
                    id: contentHit
                    anchors.fill: parent
                }

                Timer {
                    id: hideTimer
                    interval: loader.autoHideDelayMs
                    onTriggered: panelRoot.revealed = false
                }

                // HoverHandler, not MouseArea: WSideDockContent's own
                // buttons (workspace dots, app icons, toggles) each have
                // their own hoverEnabled MouseArea, and QtQuick only
                // delivers hover to the topmost MouseArea at a point - a
                // MouseArea here would lose "hovered" the instant the
                // cursor reached any dock button (firing this exit early,
                // starting the hide countdown while still over the dock),
                // and never see the real leave when the cursor finally
                // moved off (that final leave would go to the button's own
                // MouseArea instead). HoverHandler is a passive observer
                // that isn't affected by children grabbing hover/clicks
                // underneath it, so it tracks "pointer anywhere in the
                // whole dock" correctly regardless of what's under it.
                HoverHandler {
                    id: revealHover
                    enabled: loader.autoHide
                    onHoveredChanged: {
                        if (revealHover.hovered) {
                            hideTimer.stop()
                            panelRoot.revealed = true
                        } else {
                            hideTimer.restart()
                        }
                    }
                }

                Item {
                    id: slideWrap
                    anchors.fill: parent
                    y: (!loader.autoHide || panelRoot.revealed) ? 0 : (loader.edge === "top" ? -loader.thickness : loader.thickness)
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    WSideDockContent {
                        anchors.fill: parent
                        screen: panelRoot.screen
                        horizontal: true
                    }
                }
            }
        }
    }
}
