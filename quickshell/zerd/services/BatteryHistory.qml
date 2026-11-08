pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// The battery's last day: one sample every two minutes (charge, power draw, charging), kept in a file so a restart
// does not lose it. The battery popup draws its chart from this.
Singleton {
    id: root

    property var points: []          // [{ t: ms, p: 0..1, w: watts, c: charging }]
    readonly property int keepMs: 24 * 3600 * 1000
    readonly property var dev: UPower.displayDevice
    readonly property bool ready: dev.ready && dev.isLaptopBattery

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/zerd-battery-samples.json"
        onLoaded: {
            try {
                const d = JSON.parse(file.text());
                if (Array.isArray(d)) root.points = d.concat(root.points).sort((a, b) => a.t - b.t);
            } catch (e) {}
        }
    }

    function sample() {
        if (!root.ready) return;
        const now = Date.now();
        const c = dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged;
        const keep = root.points.filter(x => now - x.t < root.keepMs);
        keep.push({ t: now, p: Math.round(dev.percentage * 1000) / 1000, w: Math.round(Math.abs(dev.changeRate) * 10) / 10, c: c });
        root.points = keep;
        file.setText(JSON.stringify(keep));
    }

    Timer {
        interval: 120000
        running: root.ready
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
