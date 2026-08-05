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
    property list<var> apps: {
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

        return values;
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
