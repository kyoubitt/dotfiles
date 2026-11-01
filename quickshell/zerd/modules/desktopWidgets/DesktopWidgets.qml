pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// On/off state for the floating desktop cards. Each card's switch and
// position live in Config.options.desktopWidgets.<name> so a settings page
// can edit the same keys later. IPC: `qs -c zerd ipc call widgets <fn> [name]`.
Singleton {
    id: root

    readonly property var names: ["media", "clock", "weather", "wind", "rings", "greeting", "calendar", "agenda", "controls", "date", "day", "battery", "uptime", "worldClock", "todo", "notes", "timer", "cookieClock", "pixelClock", "stackedClock", "shape", "visualizer"]
    // Hides every card at once without touching the individual switches.
    property bool hidden: false

    function enabled(name: string): bool {
        return Config.options?.desktopWidgets?.[name]?.enable ?? false
    }
    function set(name: string, on: bool): void {
        const node = Config.options?.desktopWidgets?.[name]
        if (node) node.enable = on
    }
    function toggle(name: string): void { set(name, !enabled(name)) }

    IpcHandler {
        target: "widgets"

        function toggle(name: string): void { root.toggle(name) }
        function enable(name: string): void { root.set(name, true) }
        function disable(name: string): void { root.set(name, false) }
        function toggleAll(): void { root.hidden = !root.hidden }
        // Temperature unit for the weather card: "celsius" or "fahrenheit"
        function units(unit: string): string {
            const f = unit.toLowerCase().startsWith("f")
            if (Config.options?.bar?.weather) Config.options.bar.weather.useUSCS = f
            Weather.fetchWeather()
            return f ? "fahrenheit" : "celsius"
        }
        function list(): string {
            return root.names.map(n => `${n}: ${root.enabled(n) ? "on" : "off"}`).join("\n")
        }
    }
}
