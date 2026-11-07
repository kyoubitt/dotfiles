pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    id: root

    readonly property var raw: Svc.Weather.data
    readonly property bool useUSCS: Svc.Weather.useUSCS
    readonly property string unit: useUSCS ? "imperial" : "metric"
    readonly property string unitSym: useUSCS ? "°F" : "°C"
    readonly property string currentTempFormatted: raw.temp
    readonly property string currentTemp: String(raw.temp).replace(/[^0-9.\-]/g, "")
    readonly property bool isReady: raw.temp !== "--°C" && raw.temp !== "--°F"
    readonly property bool isLoading: false
    readonly property string currentIcon: iconFor(parseInt(raw.wCode))
    readonly property string currentHex: hexFor(parseInt(raw.wCode))

    function has(list, c) { return list.includes(c); }
    function iconFor(c) {
        const g = n => String.fromCodePoint(n);
        if (c === 113) return g(0xF0599);
        if (c === 116) return g(0xF0595);
        if (c === 119 || c === 122) return g(0xF0590);
        if (has([143, 248, 260], c)) return g(0xF0591);
        if (has([200, 386, 389, 392, 395], c)) return g(0xF0593);
        if (has([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371], c)) return g(0xF0598);
        if (has([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377], c)) return g(0xF067F);
        if (has([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359], c)) return g(0xF0597);
        return g(0xF0595);
    }
    function hexFor(c) {
        if (c === 113) return "#f9e2af";
        if (has([200, 386, 389, 392, 395], c)) return "#fab387";
        if (has([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371], c)) return "#cdd6f4";
        if (has([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359, 182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377], c)) return "#89b4fa";
        return "#f9e2af";
    }
    function textFor(c) {
        if (c === 113) return "Clear";
        if (c === 116) return "Partly cloudy";
        if (c === 119) return "Cloudy";
        if (c === 122) return "Overcast";
        if (has([143, 248, 260], c)) return "Fog";
        if (has([200, 386, 389, 392, 395], c)) return "Thunderstorm";
        if (has([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371], c)) return "Snow";
        if (has([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377], c)) return "Sleet";
        if (has([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359], c)) return "Rain";
        return "Mixed";
    }

    // The shape his calendar reads: today first, then the days after, each with its three-hour steps.
    readonly property var data: {
        const r = root.raw;
        const days = r.daily ?? [];
        const steps = r.steps ?? [];
        const forecast = days.map((d, i) => {
            const code = parseInt(d.code);
            const own = i === 0 ? (r.hourly ?? []) : steps.filter(s => s.day === d.date);
            return {
                day_full: Qt.formatDate(new Date(d.date + "T12:00:00"), "dddd"),
                icon: root.iconFor(code),
                hex: root.hexFor(code),
                max: Number(d.high),
                min: Number(d.low),
                desc: root.textFor(code),
                wind: parseInt(r.wind) || 0,
                humidity: parseInt(r.humidity) || 0,
                pop: steps.filter(s => s.day === d.date).reduce((a, s) => Math.max(a, s.rain), 0),
                feels_like: i === 0 ? (parseInt(r.tempFeelsLike) || 0) : Number(d.high),
                hourly: own.map(s => ({
                    time: String(s.hour).padStart(2, "0") + ":00",
                    temp: Number(s.temp),
                    icon: root.iconFor(parseInt(s.code)),
                    hex: root.hexFor(parseInt(s.code))
                }))
            };
        });
        return {
            offline: !root.isReady,
            city: r.city,
            current_temp: root.currentTemp,
            current_icon: root.currentIcon,
            current_hex: root.currentHex,
            forecast: forecast
        };
    }
    function refresh(force) { Svc.Weather.getData(); }
}
