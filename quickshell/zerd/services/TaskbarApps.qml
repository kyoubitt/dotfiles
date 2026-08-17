pragma Singleton

import qs.modules.common
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
    // This used to be a plain property binding that read
    // ToplevelManager.toplevels.values inside the loop - QML's automatic
    // dependency tracking doesn't reliably pick that up as a live
    // dependency (CompositorService.qml hits the same API and works around
    // it the same way: an explicit Connections/onValuesChanged), so the
    // list only ever reflected whatever was open at the exact instant this
    // singleton was first constructed and never updated after that.
    property list<var> apps: []

    function _recompute() {
        var map = new Map();

        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));

        for (const toplevel of ToplevelManager.toplevels.values) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            const key = toplevel.appId.toLowerCase();
            if (!map.has(key)) map.set(key, ({
                appId: toplevel.appId,
                toplevels: []
            }));
            map.get(key).toplevels.push(toplevel);
        }

        var values = [];
        for (const [key, value] of map) {
            values.push(appEntryComp.createObject(null, { appId: value.appId, toplevels: value.toplevels }));
        }

        root.apps = values;
    }

    Component.onCompleted: root._recompute()

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root._recompute() }
    }

    component TaskbarAppEntry: QtObject {
        id: wrapper
        required property string appId
        required property list<var> toplevels
    }
    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
