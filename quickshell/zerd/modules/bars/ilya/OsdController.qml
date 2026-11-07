pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    id: root
    property bool isFullscreen: false
    property var screen: null
    readonly property var mon: Svc.Brightness.monitors[0] ?? null
    readonly property int sysBrightness: Math.round((mon?.brightness ?? 0) * 100)
    readonly property string brightnessBackend: mon?.isDdc ? "ddc" : ""
    function setBrightness(pct) {
        const m = root.mon;
        if (m) m.setBrightness(Math.max(0.05, Math.min(1, pct / 100)));
    }
}
