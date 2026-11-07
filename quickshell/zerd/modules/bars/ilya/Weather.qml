pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    id: root

    readonly property var data: Svc.Weather.data
    readonly property int code: parseInt(data.wCode)
    readonly property string currentTempFormatted: data.temp
    readonly property string currentTemp: String(data.temp).replace(/[^0-9.\-]/g, "")
    readonly property string unitSym: String(data.temp).replace(/[0-9.\-]/g, "")
    readonly property bool isReady: data.temp !== "--°C" && data.temp !== "--°F"
    readonly property bool isLoading: false
    readonly property string currentIcon: {
        const c = root.code;
        const g = n => String.fromCodePoint(n);
        if (c === 113) return g(0xF0599);
        if (c === 116) return g(0xF0595);
        if (c === 119 || c === 122) return g(0xF0590);
        if ([143, 248, 260].includes(c)) return g(0xF0591);
        if ([200, 386, 389, 392, 395].includes(c)) return g(0xF0593);
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return g(0xF0598);
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(c)) return g(0xF067F);
        if ([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(c)) return g(0xF0597);
        return g(0xF0595);
    }
    readonly property string currentHex: {
        const c = root.code;
        if (c === 113) return "#f9e2af";
        if ([200, 386, 389, 392, 395].includes(c)) return "#fab387";
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return "#cdd6f4";
        if ([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(c)) return "#89b4fa";
        return "#f9e2af";
    }
    function refresh() { Svc.Weather.getData(); }
}
