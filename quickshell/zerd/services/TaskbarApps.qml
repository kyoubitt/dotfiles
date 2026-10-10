pragma Singleton

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    // Every currently open window, grouped by app.
    // Keyed by lowercased appId (dedup only) - each entry keeps the
    // original-cased appId, since icon-name guessing (AppSearch) relies on
    // exact casing (e.g. regex substitutions like /Minecraft.*/), and
    // lowercasing it here previously broke icon lookup for such apps.
    //
    // Sourced from CompositorService.sortedToplevels, not the raw
    // ToplevelManager.toplevels.values this used to read directly - a raw
    // toplevel's own .activate() goes through wlr-foreign-toplevel-
    // management, which niri doesn't honor (it silently drops focus-steal
    // requests from that protocol instead of raising the window), so every
    // click on an already-running pinned/taskbar icon in the dock was a
    // silent no-op there. CompositorService.sortedToplevels (built via
    // NiriService.sortToplevels/enrichToplevel, the same fix the dock's own
    // workspace dots already lean on for niri-specific actions) replaces
    // each toplevel's activate with a real niri `FocusWindow` IPC call,
    // which niri does honor.
    //
    // This used to be a plain property binding that read the toplevels
    // list inside the loop - QML's automatic dependency tracking doesn't
    // reliably pick that up as a live dependency, so the list only ever
    // reflected whatever was open at the exact instant this singleton was
    // first constructed and never updated after that. An explicit
    // Connections/onSortedToplevelsChanged below avoids the same trap.
    //
    // Entries are plain JS objects, not QtObjects built via
    // Component.createObject() (as this used to do, wrapped in a
    // `list<var>`-typed property) - a null-parented createObject() result
    // gets JavaScript ownership, and the engine's GC was reclaiming those
    // within about a second of creation even while still referenced from
    // this property, silently turning every entry to null and breaking
    // anything downstream that read it (DockAppIcon's click handler among
    // them - a pinned app's "running" check and its activate()/close()
    // calls were reading off entries that had already gone null).
    // Parenting them to root instead didn't fix it either - plain objects
    // in a plain `var` sidestep the whole QObject-lifetime question, and
    // match CompositorService.sortedToplevels' own (working) shape.
    property var apps: []

    function _recompute() {
        var map = new Map();

        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));

        for (const toplevel of CompositorService.sortedToplevels) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            const key = toplevel.appId.toLowerCase();
            if (!map.has(key)) map.set(key, ({
                appId: toplevel.appId,
                toplevels: []
            }));
            map.get(key).toplevels.push(toplevel);
        }

        root.apps = Array.from(map.values());
    }

    Component.onCompleted: root._recompute()

    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() { root._recompute() }
    }
}
