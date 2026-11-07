pragma Singleton
import QtQuick
import qs

// Where his faces called qs_manager.sh toggle <name>: opens or closes zerd's bar popup under the clicked item.
QtObject {
    function toggle(kind, item) {
        const map = { music: "media", wifi: "network", bt: "network", system: "battery" };
        const k = map[kind] ?? kind;
        if (k === "settings") { GlobalStates.settingsOpen = !GlobalStates.settingsOpen; return; }
        if (k === "launcher" || k === "applauncher") { GlobalStates.irisLauncherOpen = !GlobalStates.irisLauncherOpen; return; }
        if (GlobalStates.barPopup?.kind === k) { GlobalStates.barPopup = null; return; }
        const x = item ? item.mapToItem(null, item.width / 2, 0).x : 960;
        GlobalStates.barPopup = { kind: k, x: Math.round(x) };
    }
}
