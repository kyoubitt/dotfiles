pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    id: root

    readonly property var spaces: Svc.NiriService.allWorkspaces ?? []
    readonly property var windows: Svc.NiriService.windows ?? []

    // 0-based slot of the output's active workspace
    function activeIndexFor(outputName) {
        const ws = root.spaces.find(w => w.output === outputName && w.is_active);
        return ws ? ws.idx - 1 : 0;
    }

    readonly property var existingMap: {
        const m = {};
        for (const w of root.spaces) m[w.idx - 1] = true;
        return m;
    }
    readonly property var occupiedMap: {
        const m = {};
        const ids = {};
        for (const w of root.windows) ids[w.workspace_id] = true;
        for (const w of root.spaces) if (ids[w.id]) m[w.idx - 1] = true;
        return m;
    }
    readonly property int maxWorkspaceIndex: root.spaces.reduce((a, w) => Math.max(a, w.idx - 1), 0)

    function subscribe() {}
    function unsubscribe() {}
}
