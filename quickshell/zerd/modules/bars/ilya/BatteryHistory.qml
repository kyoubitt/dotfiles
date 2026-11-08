pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// The charge of the battery every five minutes, kept for 24 hours (also across restarts), for the battery popup's graph.
Singleton {
    id: root

    property var points: []          // { t: ms, p: percent, c: charging }
    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") ?? ((Quickshell.env("HOME") ?? "") + "/.cache")) + "/zerd-battery-history.json"
    readonly property bool present: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery

    function prune() {
        const from = Date.now() - 24 * 3600 * 1000;
        root.points = root.points.filter(x => x.t >= from);
    }
    function sample() {
        if (!root.present) return;
        const d = UPower.displayDevice;
        const next = root.points.slice();
        next.push({ t: Date.now(), p: Math.round(d.percentage * 100), c: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged });
        root.points = next;
        root.prune();
        fv.setText(JSON.stringify(root.points));
    }

    FileView {
        id: fv
        path: root.file
        onLoaded: {
            try { root.points = JSON.parse(text()); } catch (e) { root.points = []; }
            root.prune();
            root.sample();
        }
        onLoadFailed: root.sample()
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.present
        onTriggered: root.sample()
    }
    onPresentChanged: if (present && points.length === 0) sample()
}
