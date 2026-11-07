pragma Singleton
import QtQuick
import qs.modules.common as Common
import qs.services as Svc

// The settings tree the copied faces read. Only what zerd keeps in its own config is mapped; everything else
// is absent so each face falls back to its own default.
QtObject {
    id: root

    readonly property bool dataReady: true
    signal settingsLoaded()

    readonly property var top: Common.Config.options?.bars?.top ?? ({})
    readonly property var rawSettings: ({
        bar: {
            workspacesStyle: root.top.workspaceStyle === "numbers" ? "numbers" : "pills",
            hideEmptyWorkspaces: false
        },
        idle: { manualInhibit: Svc.Idle.inhibit, caffeineEndTime: 0 }
    })

    function getSetting(key, fallback) {
        const v = root.rawSettings[key];
        return v !== undefined ? v : fallback;
    }
    function setSetting(key, value) {
        if (key === "idle") Svc.Idle.toggleInhibit(!!value.manualInhibit);
    }
}
