pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.lockScreen
import qs.modules.settings
import qs.services
import "../settings/SettingsSearch.js" as Search

// The shell's settings: pages down the left under group headings, big page headers, and cards of rows on the right. Every
// row reads and writes one config path, so changes show at once. Layout after ilyamiro's settings window (serpantinum,
// AGPL-3.0: sidebar, grouped rows, search that jumps to the row) and iNiR's (page header, search scoring).
// `ipc call settings toggle|open|close|page <name>`.
Scope {
    id: root

    property bool open: false
    property int page: 0
    property string tzInfo: ""
    property string rebinding: ""          // the shortcut being changed
    readonly property var keyNames: ({ [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return",
        [Qt.Key_Space]: "Space", [Qt.Key_Tab]: "Tab", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Print]: "Print", [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_Comma]: "Comma",
        [Qt.Key_Period]: "Period", [Qt.Key_Slash]: "Slash", [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe", [Qt.Key_QuoteLeft]: "Grave",
        [Qt.Key_BracketLeft]: "BracketLeft", [Qt.Key_BracketRight]: "BracketRight", [Qt.Key_Backslash]: "Backslash" })
    // The keys of a key press as niri writes them, or "" while only modifiers are down.
    function comboOf(e: var): string {
        let k = root.keyNames[e.key] ?? ""
        if (k === "" && e.key >= Qt.Key_A && e.key <= Qt.Key_Z) k = String.fromCharCode(e.key)
        if (k === "" && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) k = String.fromCharCode(e.key)
        if (k === "" && e.key >= Qt.Key_F1 && e.key <= Qt.Key_F12) k = "F" + (e.key - Qt.Key_F1 + 1)
        if (k === "") return ""
        const m = []
        if (e.modifiers & Qt.MetaModifier) m.push("Mod")
        if (e.modifiers & Qt.ControlModifier) m.push("Ctrl")
        if (e.modifiers & Qt.AltModifier) m.push("Alt")
        if (e.modifiers & Qt.ShiftModifier) m.push("Shift")
        return m.concat([k]).join("+")
    }
    onOpenChanged: { GlobalStates.settingsOpen = root.open; if (root.open) { root.rebinding = ""; NiriBinds.reload(); tzProc.running = true } }
    Connections { target: GlobalStates; function onSettingsOpenChanged() { root.open = GlobalStates.settingsOpen } }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function close(): void { root.open = false }
        function page(name: string): void { const i = root.pages.findIndex(p => p.name.toLowerCase() === name.toLowerCase()); if (i >= 0) { root.page = i; root.open = true } }
    }

    // `nav` is the heading the page sits under in the sidebar. Rows: t = toggle | choice | step | actions | info | list | ...
    readonly property var pages: [
        { name: "Overview", nav: "", icon: "home", blurb: "Everything in one place", groups: [
            { title: "", rows: [ { t: "overview", label: "" } ] } ] },
        { name: "Profile", nav: "You", icon: "person", blurb: "Who you are, and saved set-ups", groups: [
            { title: "You", rows: [ { t: "user", label: "You" } ] },
            { title: "Saved set-ups", rows: [ { t: "profiles", icon: "badge", label: "Profiles", hint: "A profile remembers the wallpaper, the colour scheme and the main bar, dock and panel settings" } ] } ] },
        { name: "Colours", nav: "You", icon: "palette", blurb: "Wallpaper and colours", groups: [
            { title: "Wallpaper", rows: [
                { t: "wallpaper", icon: "wallpaper", label: "Wallpaper", hint: "The colours of everything come from the wallpaper", acts: [
                    { text: "Choose…", cmd: ["qs", "-c", "zerd", "ipc", "call", "wallpaper", "open"] },
                    { text: "Random", cmd: ["qs", "-c", "zerd", "ipc", "call", "wallpaper", "random"] } ] } ] },
            { title: "Colour", rows: [
                { t: "swatches", icon: "palette", label: "Accent colour", hint: "Auto takes it from the wallpaper" },
                { t: "choice", art: "scheme", icon: "contrast", label: "Scheme", hint: "Auto follows the system", path: "iris.appearance.scheme", opts: ["auto", "dark", "ink", "light"], def: "auto" },
                { t: "toggle", icon: "format_color_fill", label: "Colours follow the wallpaper (wallust)", hint: "Off keeps the solver's last palette for the dock, launcher and cards", path: "iris.wallust", def: true },
                { t: "toggle", icon: "zoom_in", label: "Dock icons magnify under the pointer", path: "iris.dock.magnification", def: true } ] } ] },
        { name: "Time", nav: "You", icon: "schedule", blurb: "Clock, dates and world clocks", groups: [
            { title: "Clock", rows: [
                { t: "preview", icon: "schedule", label: "Right now" },
                { t: "choice", icon: "schedule", label: "Clock", hint: "Bar, lock screen, clock widgets", path: "time.format", def: "hh:mm",
                  opts: [{ v: "hh:mm", l: "24-hour" }, { v: "hh:mm:ss", l: "24-hour, seconds" }, { v: "h:mm AP", l: "12-hour" }, { v: "h:mm:ss AP", l: "12-hour, seconds" }] },
                { t: "choice", icon: "calendar_month", label: "Short date", hint: "Next to the clock in the bar. d = day, M = month, y = year", path: "time.shortDateFormat", def: "dd/MM",
                  opts: ["dd/MM", "MM/dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "yyyy-MM-dd", "d MMM", "MMM d", "ddd d"].map(f => ({ v: f, l: Qt.formatDateTime(new Date(), f) })) },
                { t: "choice", icon: "event", label: "Long date", hint: "Calendar, widgets and the lock screen", path: "time.dateFormat", def: "ddd, dd/MM",
                  opts: ["ddd, dd/MM", "ddd, MM/dd", "ddd, dd/MM/yyyy", "ddd, MM/dd/yyyy", "dddd, d MMMM", "dddd, MMMM d", "dddd, MMMM d, yyyy", "ddd d MMM yyyy", "yyyy-MM-dd"].map(f => ({ v: f, l: Qt.formatDateTime(new Date(), f) })) } ] },
            { title: "Weather", rows: [
                { t: "choice", icon: "thermostat", label: "Temperature", hint: "Weather in the bar, the weather popup and widgets (Fahrenheit also switches wind to mph)", path: "bar.weather.useUSCS", def: false,
                  opts: [{ v: false, l: "Celsius (°C)" }, { v: true, l: "Fahrenheit (°F)" }] } ] },
            { title: "Time zones", rows: [
                { t: "list", icon: "public", label: "World clocks", hint: "Zones for the world clock widget, like Europe/London. Press Enter to add", path: "desktopWidgets.worldClock.timezones", keepCase: true },
                { t: "info", icon: "language", label: "System time zone", hint: "Changing it needs admin rights: timedatectl set-timezone", key: "tzInfo" } ] } ] },
        { name: "Bar", nav: "Shell", icon: "toolbar", blurb: "The top bar", groups: [
            { title: "Behaviour", rows: [
                { t: "toggle", icon: "visibility_off", label: "Hide the bar until the pointer is at the top", hint: "Rest the pointer on the top edge to bring it back", path: "bars.top.autoHide", def: false },
                { t: "toggle", icon: "fullscreen", label: "Slide away next to a fullscreen window", hint: "Only when a fullscreen and a normal window share the screen", path: "bars.top.smartHide", def: true } ] },
            { title: "Look", rows: [
                { t: "choice", art: "barlook", icon: "view_carousel", label: "Bar style", hint: "Pills: a capsule per group. Strip: one full-width bar. Floating: one rounded bar", path: "bars.top.look", opts: [{ v: "pills", l: "Pills" }, { v: "strip", l: "Strip" }, { v: "floating", l: "Floating" }], def: "pills" },
                { t: "step", icon: "apps", label: "Tray icons before \"more\"", path: "bars.top.trayMax", min: 2, max: 12, by: 1, def: 6 },
                { t: "step", icon: "height", label: "Bar height", path: "bars.top.height", min: 28, max: 44, by: 2, def: 34 } ] },
            { title: "Layout", rows: [
                { t: "actions", icon: "dashboard_customize", label: "Layout", hint: "Drag the blocks where you want them, hide what you don't use. Window titles can show private chats, so that block starts hidden", acts: [
                    { text: "Edit bar layout", cmd: ["qs", "-c", "zerd", "ipc", "call", "baredit", "open"] },
                    { text: "Reset to default", cmd: ["qs", "-c", "zerd", "ipc", "call", "baredit", "reset"] } ] } ] } ] },
        { name: "Dock", nav: "Shell", icon: "dock_to_bottom", blurb: "The app dock", groups: [
            { title: "Behaviour", rows: [
                { t: "toggle", icon: "visibility_off", label: "Hide the dock until the pointer is at the edge", hint: "Rest the pointer on the screen edge to show it", path: "iris.dock.autoHide", def: true },
                { t: "toggle", icon: "vertical_align_bottom", label: "Attach to the screen edge", hint: "The dock grows out of the bottom edge with curved corners, like a notch", path: "iris.dock.notch", def: false },
                { t: "toggle", icon: "drag_indicator", label: "Drag icons to reorder", path: "iris.dock.reorder", def: true } ] },
            { title: "Look", rows: [
                { t: "choice", art: "dockstyle", icon: "dock_to_bottom", label: "Style", hint: "Tiles: every icon on its own dark square in a flat plate. Classic: the floating pill", path: "iris.dock.style", opts: ["tiles", "classic"], def: "tiles" },
                { t: "step", icon: "fit_screen", label: "Icon size", path: "iris.dock.iconSize", min: 28, max: 64, by: 2, def: 40 },
                { t: "toggle", icon: "zoom_in", label: "Magnify icons under the pointer", path: "iris.dock.magnification", def: true },
                { t: "toggle", icon: "notifications_active", label: "Badges", path: "iris.dock.badges", def: true } ] },
            { title: "Spectrum", rows: [
                { t: "toggle", icon: "equalizer", label: "Spectrum", hint: "Moves with the music while a song plays", path: "iris.dock.cava.enable", def: true },
                { t: "choice", art: "spectrum", icon: "graphic_eq", label: "Spectrum style", hint: "Wave: a soft hill along the bottom of the screen. Inside: bars in the dock plate", path: "iris.dock.cava.style", opts: ["wave", "inside"], def: "wave" } ] } ] },
        { name: "Panels", nav: "Shell", icon: "side_navigation", blurb: "The quick panel and the sections panel", groups: [
            { title: "Edge panels", rows: [
                { t: "toggle", icon: "side_navigation", label: "Open a panel from the screen edge", hint: "The pointer has to move onto the edge and rest there", path: "bars.sidebars.edgeHover", def: true },
                { t: "choice", art: "edges", icon: "swap_horiz", label: "Edges", path: "bars.sidebars.edgeSide", opts: ["left", "right", "both"], def: "both" },
                { t: "toggle", icon: "do_not_disturb_on", label: "Focus timer turns Do not disturb on", path: "bars.sidebars.focusDnd", def: true } ] } ] },
        { name: "Launcher", nav: "Shell", icon: "apps", blurb: "The app list", groups: [
            { title: "App list", rows: [
                { t: "list", icon: "hide_source", label: "Hidden from the app list", hint: "Part of an app's name or id. Typing the name still finds it", path: "iris.launcher.hidden" } ] } ] },
        { name: "Widgets", nav: "Shell", icon: "widgets", blurb: "The desktop widget board", groups: [
            { title: "Desktop widgets", rows: [
                { t: "cards", icon: "widgets", label: "Desktop widgets", hint: "Tap to show or hide one. They sit on the wallpaper, under your windows" },
                { t: "actions", icon: "open_with", label: "Arrange", hint: "Drag them where you want them", acts: [
                    { text: "Arrange on screen", cmd: ["qs", "-c", "zerd", "ipc", "call", "widgetboard", "toggle"] },
                    { text: "Show all", cmd: ["qs", "-c", "zerd", "ipc", "call", "widgets", "toggleAll"] } ] } ] },
            { title: "Board", rows: [
                { t: "choice", icon: "grid_4x4", label: "Board grid (px, 0 = off)", path: "bars.board.grid", opts: [0, 8, 16, 32, 64], def: 32 },
                { t: "toggle", icon: "magnet", label: "Snap to the grid", path: "bars.board.snap", def: true },
                { t: "toggle", icon: "grid_on", label: "Draw the grid", path: "bars.board.showGrid", def: true } ] } ] },
        { name: "Controls", nav: "Behaviour", icon: "keyboard", blurb: "Keyboard shortcuts", groups: [
            { title: "Shortcuts", rows: [
                { t: "binds", icon: "keyboard", label: "Keyboard shortcuts", hint: "Click Change, then press the new keys. Keys that are already taken run their own action instead" } ] } ] },
        { name: "Notifications", nav: "Behaviour", icon: "notifications", blurb: "Banners", groups: [
            { title: "Banners", rows: [
                { t: "choice", icon: "notifications", label: "Banners", path: "bars.notifications.engine", opts: ["inir", "waffle"], def: "inir" },
                { t: "choice", art: "banner", icon: "vertical_align_top", label: "Position", path: "bars.notifications.position", opts: ["top", "bottom"], def: "top" },
                { t: "step", icon: "straighten", label: "Width", path: "bars.notifications.width", min: 300, max: 520, by: 20, def: 380 } ] } ] },
        { name: "Feedback", nav: "Behaviour", icon: "volume_up", blurb: "Pills and confirmations", groups: [
            { title: "Volume and brightness", rows: [
                { t: "toggle", icon: "volume_up", label: "Volume and brightness pill", path: "bars.osd.enable", def: true },
                { t: "choice", art: "pill", icon: "vertical_align_bottom", label: "Pill position", path: "bars.osd.position", opts: ["bottom", "top"], def: "bottom" },
                { t: "step", icon: "timer", label: "Pill time (ms)", path: "bars.osd.timeout", min: 800, max: 4000, by: 100, def: 1500 } ] },
            { title: "Closing windows", rows: [
                { t: "toggle", icon: "help", label: "Ask before closing important apps", hint: "Mod+Q closes at once when this is off", path: "closeConfirm.enabled", def: false } ] } ] }
    ]

    Process {
        id: tzProc
        command: ["sh", "-c", "timedatectl show -p Timezone -p NTP --value | paste -sd'|' | sed 's/|/   ·   automatic time: /'"]
        stdout: StdioCollector { onStreamFinished: root.tzInfo = text.trim() }
    }

    LazyLoader {
        active: root.open
        component: FloatingWindow {
            id: win
            title: "zerd-settings"
            implicitWidth: 940
            implicitHeight: 640
            color: BarStyle.surface
            visible: true
            onVisibleChanged: if (!visible) root.open = false

            Keys.onEscapePressed: root.open = false

            Item {
                id: view
                objectName: "settingsView"
                anchors.fill: parent
                focus: true

                property string query: ""
                property string highlightId: ""
                property var rows: ({})                // rowId -> the row, for jumping to it
                property var flicks: ({})              // page index -> its Flickable
                property string pendingId: ""
                property int tries: 0
                property int picked: 0                 // the selected search result
                readonly property var results: Search.search(index, view.query)
                readonly property var index: Search.buildIndex(root.pages, NiriBinds.list.map(b => ({ name: NiriBinds.nameOf(b), key: b.key })))
                readonly property bool searching: query.trim().length > 0
                onQueryChanged: picked = 0

                // what Reset page puts back: every row of this page that has a default
                readonly property var resettable: {
                    const out = []
                    for (const g of root.pages[root.page].groups) for (const r of g.rows) {
                        if (r.t === "swatches") out.push({ path: "colours.accent", def: "" })
                        else if (r.path && r.def !== undefined) out.push({ path: r.path, def: r.def })
                    }
                    return out
                }
                function resetPage(): void { for (const r of view.resettable) Config.setNestedValue(r.path, r.def) }

                function jump(e: var): void {
                    searchIn.text = ""
                    root.page = e.page
                    view.pendingId = e.id
                    view.tries = 0
                    jumpTimer.restart()
                }
                Timer {
                    id: jumpTimer
                    interval: 50
                    onTriggered: {
                        const row = view.rows[view.pendingId]
                        const flick = view.flicks[root.page]
                        if (!row || !flick) { if (view.tries++ < 14) jumpTimer.restart(); return }
                        const y = row.mapToItem(flick.contentItem, 0, 0).y
                        scrollAnim.stop()
                        scrollAnim.target = flick
                        scrollAnim.to = Math.max(0, Math.min(y - flick.height / 2 + row.height / 2, flick.contentHeight - flick.height))
                        scrollAnim.start()
                        view.highlightId = ""
                        view.highlightId = view.pendingId
                    }
                }
                NumberAnimation { id: scrollAnim; property: "contentY"; duration: 260; easing.type: Easing.OutCubic }

                // typing anywhere starts a search; Ctrl+K or / goes to the box
                Keys.onPressed: event => {
                    if (searchIn.activeFocus || root.rebinding !== "") return
                    if (event.key === Qt.Key_Escape) { root.open = false; event.accepted = true; return }
                    const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    if ((event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Slash) {
                        searchIn.forceActiveFocus(); event.accepted = true
                    } else if (plain && event.text.length === 1 && event.text >= " ") {
                        searchIn.forceActiveFocus(); searchIn.text = event.text; searchIn.cursorPosition = 1; event.accepted = true
                    }
                }

                // ---- Sidebar
                Rectangle {
                    id: nav
                    width: 232; height: parent.height
                    color: Qt.darker(BarStyle.surface, 1.25)

                    Row {
                        id: who
                        x: 20; y: 18; spacing: 10
                        LockAvatar { size: 38 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            BarText { text: Config.options?.account?.name || SystemInfo.displayName; font.pixelSize: 14; font.weight: Font.DemiBold }
                            BarText { text: Profiles.active !== "" ? Profiles.active : "Settings"; font.pixelSize: 11; color: BarStyle.subtext }
                        }
                    }
                    Rectangle {
                        id: searchBox
                        x: 14; y: 70; width: nav.width - 28; height: 36; radius: 18
                        color: BarStyle.plate; border.width: 1; border.color: searchIn.activeFocus ? BarStyle.accent : BarStyle.border
                        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: BarStyle.subtext }
                        TextInput {
                            id: searchIn
                            x: 38; width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter
                            color: BarStyle.text; font.pixelSize: BarStyle.fontSize; font.family: Appearance.font.family.expressive; clip: true
                            renderType: Text.NativeRendering
                            onTextChanged: view.query = text
                            Keys.onEscapePressed: { if (text.length > 0) text = ""; else view.forceActiveFocus() }
                            Keys.onDownPressed: view.picked = Math.min(view.results.length - 1, view.picked + 1)
                            Keys.onUpPressed: view.picked = Math.max(0, view.picked - 1)
                            Keys.onReturnPressed: if (view.results.length > 0) view.jump(view.results[view.picked])
                            Keys.onEnterPressed: if (view.results.length > 0) view.jump(view.results[view.picked])
                        }
                        BarText { x: 38; anchors.verticalCenter: parent.verticalCenter; visible: searchIn.text.length === 0; text: "Search settings"; color: BarStyle.subtext }
                    }

                    // heading rows and page rows with their y worked out once, so the pill can slide between them
                    readonly property var entries: {
                        const out = []
                        let y = 0, last = null
                        for (let i = 0; i < root.pages.length; i++) {
                            const n = root.pages[i].nav
                            if (n !== last) { last = n; if (n !== "") { y += out.length > 0 ? 8 : 0; out.push({ heading: n, y: y }); y += 28 } }
                            out.push({ page: i, y: y }); y += 35
                        }
                        return out
                    }
                    readonly property var pageY: { const m = []; for (const e of entries) if (e.page !== undefined) m[e.page] = e.y; return m }
                    Flickable {
                        x: 0; y: 118; width: nav.width; height: nav.height - 118
                        contentHeight: navBody.height + 2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Item {
                            id: navBody
                            x: 12; width: nav.width - 24
                            height: nav.entries[nav.entries.length - 1].y + 34
                            Rectangle {
                                y: nav.pageY[root.page] ?? 0; width: parent.width; height: 34; radius: 17
                                color: BarStyle.accentContainer
                                Behavior on y { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: BarStyle.easeExpressive } }
                            }
                            Repeater {
                                model: nav.entries
                                delegate: Item {
                                    id: ent
                                    required property var modelData
                                    readonly property bool isPage: modelData.page !== undefined
                                    readonly property bool on: isPage && root.page === modelData.page
                                    y: modelData.y; width: navBody.width; height: isPage ? 34 : 24
                                    BarText {
                                        visible: !ent.isPage
                                        x: 14; y: 3; text: String(ent.modelData.heading ?? "").toUpperCase()
                                        font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 0.9; color: BarStyle.text; opacity: 0.72
                                    }
                                    Row {
                                        visible: ent.isPage
                                        x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: ent.isPage ? root.pages[ent.modelData.page].icon : ""; size: 20; fill: ent.on ? 1 : 0; color: ent.on ? BarStyle.onAccentContainer : BarStyle.subtext }
                                        BarText { anchors.verticalCenter: parent.verticalCenter; text: ent.isPage ? root.pages[ent.modelData.page].name : ""; font.weight: ent.on ? Font.DemiBold : Font.Medium; color: ent.on ? BarStyle.onAccentContainer : BarStyle.text }
                                    }
                                    HoverHandler { id: navHover; enabled: ent.isPage; cursorShape: Qt.PointingHandCursor }
                                    Rectangle { visible: ent.isPage && !ent.on && navHover.hovered; anchors.fill: parent; radius: 17; color: BarStyle.plateHover; z: -1 }
                                    TapHandler { enabled: ent.isPage; onTapped: { searchIn.text = ""; root.page = ent.modelData.page; view.forceActiveFocus() } }
                                }
                            }
                        }
                    }
                }

                // ---- Pages: each is built the first time it is shown and then kept, so switching is instant
                Item {
                    id: host
                    x: nav.width; width: parent.width - nav.width; height: parent.height - footer.height
                    clip: true
                    Repeater {
                        model: root.pages.length
                        delegate: Loader {
                            id: pageLoader
                            required property int index
                            property bool seen: root.page === index
                            onSeenChanged: if (seen) active = true
                            width: host.width; height: host.height
                            active: false
                            visible: root.page === index
                            Component.onCompleted: if (seen) active = true
                            sourceComponent: pageComp
                        }
                    }
                    Component {
                        id: pageComp
                        Flickable {
                            id: flick
                            readonly property int pageIndex: parent ? parent.index : 0
                            readonly property var pg: root.pages[pageIndex]
                            anchors.fill: parent
                            contentHeight: body.height + 80
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Component.onCompleted: view.flicks[pageIndex] = flick

                            Column {
                                id: body
                                x: 32; y: 32; width: flick.width - 64; spacing: 16
                                // the big header
                                Item {
                                    width: body.width; height: 64
                                    Rectangle {
                                        id: badge
                                        width: 56; height: 56; radius: 20
                                        color: BarStyle.accentContainer
                                        BarIcon { anchors.centerIn: parent; name: flick.pg.icon; size: 28; fill: 1; color: BarStyle.onAccentContainer }
                                    }
                                    Column {
                                        x: 74; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        BarText { text: flick.pg.name; font.pixelSize: 30; font.weight: Font.DemiBold }
                                        BarText { text: flick.pg.blurb; font.pixelSize: 13; color: BarStyle.subtext }
                                    }
                                }
                                Repeater {
                                    model: flick.pg.groups
                                    delegate: SettingsCard {
                                        id: card
                                        required property var modelData
                                        required property int index
                                        title: modelData.title
                                        Repeater {
                                            id: rowRep
                                            model: card.modelData.rows
                                            delegate: SettingsRow {
                                                id: row
                                                required property var modelData
                                                required property int index
                                                readonly property var spec: modelData
                                                readonly property var value: Config.getNestedValue(spec.path, spec.def)
                                                readonly property bool block: ["list", "profiles", "binds", "cards", "swatches", "overview", "user", "wallpaper"].includes(spec.t)
                                                rowId: "p" + flick.pageIndex + "g" + card.index + "r" + index
                                                registry: view.rows
                                                highlightId: view.highlightId
                                                title: spec.t === "overview" || spec.t === "user" ? "" : spec.label
                                                icon: spec.t === "overview" || spec.t === "user" ? "" : (spec.icon ?? "")
                                                hint: spec.t === "overview" ? "" : (spec.hint ?? "")
                                                stacked: block || !!spec.art || (spec.t === "choice" && (spec.opts?.length ?? 0) > 5) || (spec.t === "actions" && (spec.hint?.length ?? 0) > 46)
                                                clickable: spec.t === "toggle"
                                                divider: index < rowRep.count - 1
                                                onTapped: Config.setNestedValue(spec.path, !value)
                                                readonly property real inner: width - 32

                                                Loader {
                                                    sourceComponent: ({ toggle: toggleC, choice: row.spec.art ? artC : (row.stacked ? wrapC : chipsC), step: stepC, actions: actionsC, info: infoC,
                                                        preview: previewC, user: userC, profiles: profilesC, binds: bindsC, cards: cardsC, swatches: swatchC, list: listC,
                                                        overview: overviewC, wallpaper: wallpaperC })[row.spec.t]
                                                }

                                                // ---- controls
                                                Component { id: toggleC; BarSwitch { checked: !!row.value; onToggled: Config.setNestedValue(row.spec.path, !row.value) } }
                                                Component {
                                                    id: chipC
                                                    BarButton {
                                                        id: chip
                                                        required property var modelData
                                                        readonly property var v: typeof modelData === "object" ? modelData.v : modelData
                                                        readonly property bool on: row.value === v
                                                        tone: row.stacked ? "outlined" : "plain"
                                                        toggled: on
                                                        width: chipText.implicitWidth + 24; height: 32; radius: 16
                                                        onTapped: Config.setNestedValue(row.spec.path, chip.v)
                                                        BarText { id: chipText; anchors.centerIn: parent; text: typeof chip.modelData === "object" ? chip.modelData.l : String(chip.modelData); color: chip.ink; font.weight: chip.on ? Font.DemiBold : Font.Medium }
                                                    }
                                                }
                                                Component {
                                                    id: chipsC
                                                    Item {
                                                        width: chipRow.width + 8; height: 38
                                                        Rectangle { anchors.fill: parent; radius: 19; color: BarStyle.surface }
                                                        Row { id: chipRow; x: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                                            Repeater { model: row.spec.opts ?? []; delegate: chipC } }
                                                    }
                                                }
                                                Component { id: wrapC; Flow { width: row.inner; spacing: 6; Repeater { model: row.spec.opts ?? []; delegate: chipC } } }
                                                Component {
                                                    id: artC
                                                    Row {
                                                        spacing: 10
                                                        Repeater {
                                                            model: row.spec.opts ?? []
                                                            delegate: ArtTile {
                                                                required property var modelData
                                                                art: row.spec.art; val: String(modelData)
                                                                label: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                                                                selected: row.value === modelData
                                                                onTapped: Config.setNestedValue(row.spec.path, modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                                Component {
                                                    id: stepC
                                                    Row {
                                                        spacing: 6
                                                        BarButton {
                                                            tone: "outlined"; width: 32; height: 32; radius: 16
                                                            onTapped: Config.setNestedValue(row.spec.path, Math.max(row.spec.min, Number(row.value) - row.spec.by))
                                                            BarIcon { anchors.centerIn: parent; name: "remove"; size: 18; color: BarStyle.text }
                                                        }
                                                        BarText { width: 52; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: String(row.value); font.weight: Font.DemiBold }
                                                        BarButton {
                                                            tone: "outlined"; width: 32; height: 32; radius: 16
                                                            onTapped: Config.setNestedValue(row.spec.path, Math.min(row.spec.max, Number(row.value) + row.spec.by))
                                                            BarIcon { anchors.centerIn: parent; name: "add"; size: 18; color: BarStyle.text }
                                                        }
                                                    }
                                                }
                                                Component {
                                                    id: actionsC
                                                    Row {
                                                        spacing: 6
                                                        Repeater {
                                                            model: row.spec.acts ?? []
                                                            delegate: BarButton {
                                                                id: ab
                                                                required property var modelData
                                                                tone: "filled"
                                                                width: abText.implicitWidth + 30; height: 34; radius: 17
                                                                onTapped: Quickshell.execDetached(ab.modelData.cmd)
                                                                BarText { id: abText; anchors.centerIn: parent; text: ab.modelData.text; font.pixelSize: 12; font.weight: Font.Medium; color: ab.ink }
                                                            }
                                                        }
                                                    }
                                                }
                                                Component { id: infoC; BarText { text: root[row.spec.key ?? ""] ?? ""; color: BarStyle.accent; font.weight: Font.Medium } }
                                                Component {
                                                    id: previewC
                                                    Column {
                                                        spacing: 2
                                                        BarText { anchors.right: parent.right; text: DateTime.time; font.pixelSize: 28; font.weight: Font.DemiBold }
                                                        BarText { anchors.right: parent.right; text: DateTime.date + "   ·   " + DateTime.shortDate; color: BarStyle.subtext }
                                                    }
                                                }

                                                // ---- the wallpaper in use, with its buttons
                                                Component {
                                                    id: wallpaperC
                                                    Row {
                                                        spacing: 16
                                                        ClippingRectangle {
                                                            width: 176; height: 99; radius: BarStyle.radiusSmall; color: BarStyle.surface
                                                            Image { anchors.fill: parent; source: WallpaperState.thumbUrl(WallpaperState.current); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 352 }
                                                        }
                                                        Row {
                                                            anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                                            Repeater {
                                                                model: row.spec.acts
                                                                delegate: BarButton {
                                                                    id: wb
                                                                    required property var modelData
                                                                    tone: "filled"
                                                                    width: wbText.implicitWidth + 30; height: 34; radius: 17
                                                                    onTapped: Quickshell.execDetached(wb.modelData.cmd)
                                                                    BarText { id: wbText; anchors.centerIn: parent; text: wb.modelData.text; font.pixelSize: 12; font.weight: Font.Medium; color: wb.ink }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // ---- the person: picture, name, and buttons to change them
                                                Component {
                                                    id: userC
                                                    Item {
                                                        width: row.inner; height: 96
                                                        LockAvatar { x: 0; anchors.verticalCenter: parent.verticalCenter; size: 78 }
                                                        Rectangle {
                                                            x: 100; y: 10; width: 280; height: 36; radius: 18
                                                            color: BarStyle.surface; border.width: 1; border.color: nameIn.activeFocus ? BarStyle.accent : BarStyle.border
                                                            TextInput {
                                                                id: nameIn
                                                                x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter
                                                                color: BarStyle.text; font.pixelSize: 16; font.weight: Font.DemiBold; clip: true
                                                                font.family: Appearance.font.family.expressive
                                                                text: Config.options?.account?.name || SystemInfo.displayName
                                                                onEditingFinished: Config.setNestedValue("account.name", text.trim())
                                                            }
                                                        }
                                                        Row {
                                                            x: 100; y: 56; spacing: 8
                                                            Repeater {
                                                                model: [{ text: "Change picture…", a: "pick" }, { text: "Remove picture", a: "clear" }]
                                                                delegate: BarButton {
                                                                    id: ub
                                                                    required property var modelData
                                                                    tone: "outlined"
                                                                    width: ubText.implicitWidth + 28; height: 30; radius: 15
                                                                    onTapped: { if (ub.modelData.a === "pick") picker.running = true; else Config.setNestedValue("account.avatar", "") }
                                                                    BarText { id: ubText; anchors.centerIn: parent; text: ub.modelData.text; font.pixelSize: 12; color: ub.ink }
                                                                }
                                                            }
                                                        }
                                                        Process {
                                                            id: picker
                                                            command: ["zenity", "--file-selection", "--title=Profile picture", "--file-filter=Images | *.png *.jpg *.jpeg *.webp", "--filename=" + Quickshell.env("HOME") + "/Pictures/"]
                                                            stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f.length > 0) Config.setNestedValue("account.avatar", f) } }
                                                        }
                                                    }
                                                }

                                                // ---- saved set-ups
                                                Component {
                                                    id: profilesC
                                                    Column {
                                                        id: profCol
                                                        width: row.inner; spacing: 6
                                                        Repeater {
                                                            model: Profiles.list
                                                            delegate: Rectangle {
                                                                id: prof
                                                                required property var modelData
                                                                readonly property bool on: Profiles.active === modelData.name
                                                                width: profCol.width; height: 46; radius: 14
                                                                color: on ? BarStyle.accentContainer : "transparent"
                                                                border.width: 1; border.color: on ? BarStyle.accent : BarStyle.border
                                                                Image {
                                                                    x: 8; anchors.verticalCenter: parent.verticalCenter; width: 52; height: 32
                                                                    source: WallpaperState.thumbUrl(prof.modelData.wallpaper)
                                                                    fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 120
                                                                }
                                                                BarText { x: 72; anchors.verticalCenter: parent.verticalCenter; text: prof.modelData.name; font.weight: Font.DemiBold }
                                                                Row {
                                                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                                                    spacing: 6
                                                                    BarButton {
                                                                        id: applyBtn
                                                                        tone: "filled"; width: 64; height: 30; radius: 15
                                                                        onTapped: Profiles.apply(prof.modelData.name)
                                                                        BarText { anchors.centerIn: parent; text: prof.on ? "Active" : "Apply"; font.pixelSize: 12; color: applyBtn.ink }
                                                                    }
                                                                    BarButton {
                                                                        tone: "plain"; width: 30; height: 30; radius: 15
                                                                        onTapped: Profiles.remove(prof.modelData.name)
                                                                        BarIcon { anchors.centerIn: parent; name: "delete"; size: 17; color: BarStyle.subtext }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        Row {
                                                            spacing: 8
                                                            Rectangle {
                                                                width: 240; height: 34; radius: 17; color: BarStyle.surface; border.width: 1; border.color: profIn.activeFocus ? BarStyle.accent : BarStyle.border
                                                                TextInput {
                                                                    id: profIn
                                                                    x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                                                                    color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                                                                    font.family: Appearance.font.family.expressive
                                                                    onAccepted: { Profiles.capture(text); text = "" }
                                                                }
                                                                BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: profIn.text.length === 0; text: "Name for the current set-up"; color: BarStyle.subtext; font.pixelSize: 12 }
                                                            }
                                                            BarButton {
                                                                id: saveBtn
                                                                tone: "filled"; width: 70; height: 34; radius: 17
                                                                onTapped: { Profiles.capture(profIn.text); profIn.text = "" }
                                                                BarText { anchors.centerIn: parent; text: "Save"; font.pixelSize: 12; font.weight: Font.DemiBold; color: saveBtn.ink }
                                                            }
                                                        }
                                                    }
                                                }

                                                // ---- accent colours: the wallpaper's, then a few fixed ones
                                                Component {
                                                    id: swatchC
                                                    Column {
                                                      spacing: 16
                                                      Row {
                                                        spacing: 10
                                                        Repeater {
                                                            model: [{ hex: "" }].concat(["#ef5350", "#ff7043", "#ffca28", "#66bb6a", "#26a69a", "#42a5f5", "#7e57c2", "#ec407a", "#bdbdbd"].map(h => ({ hex: h })))
                                                            delegate: Rectangle {
                                                                id: sw
                                                                required property var modelData
                                                                readonly property bool on: (Config.options?.colours?.accent ?? "") === modelData.hex
                                                                width: 34; height: 34; radius: 17
                                                                color: modelData.hex === "" ? WallustTheme.wallAccent : modelData.hex
                                                                border.width: on ? 3 : 1; border.color: on ? BarStyle.text : BarStyle.border
                                                                scale: swHov.hovered ? 1.1 : 1
                                                                Behavior on scale { NumberAnimation { duration: 90 } }
                                                                BarIcon { anchors.centerIn: parent; visible: sw.modelData.hex === ""; name: "wallpaper"; size: 16; color: "#000000"; opacity: 0.7 }
                                                                BarIcon { anchors.centerIn: parent; visible: sw.on && sw.modelData.hex !== ""; name: "check"; size: 18; color: "#000000"; opacity: 0.75 }
                                                                HoverHandler { id: swHov; cursorShape: Qt.PointingHandCursor }
                                                                TapHandler { onTapped: Config.setNestedValue("colours.accent", sw.modelData.hex) }
                                                            }
                                                        }
                                                      }
                                                      // the accent as it will look: a filled button, a tonal chip, a bar, a switch
                                                      Row {
                                                        spacing: 16
                                                        Rectangle { width: 92; height: 34; radius: 17; color: BarStyle.accent
                                                            BarText { anchors.centerIn: parent; text: "Button"; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.onAccent } }
                                                        Rectangle { width: 92; height: 34; radius: 17; color: BarStyle.accentContainer
                                                            BarText { anchors.centerIn: parent; text: "Chip"; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.onAccentContainer } }
                                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 120; height: 8; radius: 4; color: BarStyle.cardHigh
                                                            Rectangle { width: 72; height: 8; radius: 4; color: BarStyle.accent } }
                                                        BarSwitch { checked: true; enabled: false }
                                                      }
                                                    }
                                                }

                                                // ---- a list of words: each one with a remove button, and a field to add
                                                Component {
                                                    id: listC
                                                    Column {
                                                        width: row.inner; spacing: 8
                                                        Flow {
                                                            width: parent.width; spacing: 6
                                                            Repeater {
                                                                model: Config.getNestedValue(row.spec.path, [])
                                                                delegate: Rectangle {
                                                                    id: tag
                                                                    required property var modelData
                                                                    height: 28; radius: 14; width: tagText.implicitWidth + 40
                                                                    color: BarStyle.cardHigh
                                                                    BarText { id: tagText; x: 12; anchors.verticalCenter: parent.verticalCenter; text: String(tag.modelData); font.pixelSize: 12 }
                                                                    BarIcon { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } name: "close"; size: 14; color: BarStyle.subtext }
                                                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                                                    TapHandler { onTapped: Config.setNestedValue(row.spec.path, Config.getNestedValue(row.spec.path, []).filter(w => w !== tag.modelData)) }
                                                                }
                                                            }
                                                        }
                                                        Rectangle {
                                                            width: 240; height: 32; radius: 16; color: BarStyle.surface; border.width: 1; border.color: addIn.activeFocus ? BarStyle.accent : BarStyle.border
                                                            TextInput {
                                                                id: addIn
                                                                x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                                                                color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                                                                font.family: Appearance.font.family.expressive
                                                                onAccepted: { const w = row.spec.keepCase ? text.trim() : text.trim().toLowerCase(); if (w.length > 0) Config.setNestedValue(row.spec.path, Config.getNestedValue(row.spec.path, []).concat([w])); text = "" }
                                                            }
                                                            BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: addIn.text.length === 0; text: "Add a name, then Enter"; color: BarStyle.subtext; font.pixelSize: 12 }
                                                        }
                                                    }
                                                }

                                                // ---- desktop widgets: a tile for each
                                                Component {
                                                    id: cardsC
                                                    Flow {
                                                        width: row.inner; spacing: 8
                                                        Repeater {
                                                            model: WidgetRegistry.cards
                                                            delegate: BarButton {
                                                                id: tile
                                                                required property var modelData
                                                                readonly property bool on: Config.getNestedValue("desktopWidgets." + modelData.name + ".enable", false)
                                                                tone: "outlined"; toggled: on
                                                                width: tileRow.implicitWidth + 26; height: 38; radius: 19
                                                                onTapped: Config.setNestedValue("desktopWidgets." + tile.modelData.name + ".enable", !tile.on)
                                                                Row {
                                                                    id: tileRow
                                                                    anchors.centerIn: parent; spacing: 7
                                                                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: tile.on ? "check" : tile.modelData.icon; size: 17; color: tile.inkSoft }
                                                                    BarText { anchors.verticalCenter: parent.verticalCenter; text: tile.modelData.title; font.pixelSize: 12; font.weight: Font.Medium; color: tile.ink }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // ---- every keyboard shortcut, with a button to change each
                                                Component {
                                                    id: bindsC
                                                    Column {
                                                        id: bindsCol
                                                        width: row.inner; spacing: 2
                                                        BarText { visible: NiriBinds.message.length > 0; text: NiriBinds.message; color: NiriBinds.message === "Changed" ? BarStyle.accent : BarStyle.danger; font.pixelSize: 12 }
                                                        Repeater {
                                                            model: NiriBinds.list
                                                            delegate: Item {
                                                                id: bind
                                                                required property var modelData
                                                                readonly property bool editing: root.rebinding === modelData.key
                                                                readonly property string rowId: "bind:" + modelData.key
                                                                width: bindsCol.width; height: 44
                                                                Component.onCompleted: view.rows[rowId] = bind
                                                                Component.onDestruction: if (view.rows[rowId] === bind) delete view.rows[rowId]
                                                                BarHoverFill { anchors.fill: parent; hovered: bindHov.hovered || bind.editing }
                                                                Rectangle {
                                                                    id: bflash
                                                                    anchors.fill: parent; radius: BarStyle.radiusSmall; color: BarStyle.accent; opacity: 0
                                                                    SequentialAnimation { id: bAnim
                                                                        NumberAnimation { target: bflash; property: "opacity"; to: 0.28; duration: 280 }
                                                                        PauseAnimation { duration: 1100 }
                                                                        NumberAnimation { target: bflash; property: "opacity"; to: 0; duration: 700 } }
                                                                }
                                                                Connections { target: view; function onHighlightIdChanged() { if (view.highlightId === bind.rowId) bAnim.restart() } }
                                                                HoverHandler { id: bindHov }
                                                                BarText { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 320; elide: Text.ElideRight; text: NiriBinds.nameOf(bind.modelData) }
                                                                Row {
                                                                    visible: !bind.editing
                                                                    anchors { right: changeBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                                    spacing: 4
                                                                    Repeater {
                                                                        model: bind.modelData.key.split("+")
                                                                        delegate: Rectangle {
                                                                            id: cap
                                                                            required property var modelData
                                                                            height: 26; width: Math.max(26, capText.implicitWidth + 16); radius: 8
                                                                            color: BarStyle.surface; border.width: 1; border.color: BarStyle.border
                                                                            BarText { id: capText; anchors.centerIn: parent; text: cap.modelData === "Mod" ? "Super" : cap.modelData; font.pixelSize: 11; font.weight: Font.Medium }
                                                                        }
                                                                    }
                                                                }
                                                                Rectangle {
                                                                    id: capture
                                                                    visible: bind.editing
                                                                    anchors { right: changeBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                                    width: 230; height: 30; radius: 15; color: BarStyle.surface; border.width: 2; border.color: BarStyle.accent
                                                                    property string combo: ""
                                                                    onVisibleChanged: if (visible) { combo = ""; grab.forceActiveFocus() }
                                                                    BarText { anchors.centerIn: parent; text: capture.combo.length > 0 ? capture.combo.replace("Mod", "Super") : "Press the new keys…"; font.pixelSize: 12; color: capture.combo.length > 0 ? BarStyle.text : BarStyle.subtext }
                                                                    Item {
                                                                        id: grab
                                                                        focus: bind.editing
                                                                        Keys.onPressed: event => {
                                                                            event.accepted = true
                                                                            if (event.key === Qt.Key_Escape) { root.rebinding = ""; return }
                                                                            const c = root.comboOf(event)
                                                                            if (c !== "") capture.combo = c
                                                                        }
                                                                    }
                                                                }
                                                                BarButton {
                                                                    id: changeBtn
                                                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                                                    tone: bind.editing && capture.combo.length > 0 ? "filled" : "outlined"
                                                                    width: 76; height: 30; radius: 15
                                                                    onTapped: {
                                                                        if (!bind.editing) { NiriBinds.message = ""; root.rebinding = bind.modelData.key }
                                                                        else if (capture.combo.length > 0) { NiriBinds.rebind(bind.modelData.key, capture.combo); root.rebinding = "" }
                                                                        else root.rebinding = ""
                                                                    }
                                                                    BarText { anchors.centerIn: parent; font.pixelSize: 12; text: bind.editing ? (capture.combo.length > 0 ? "Save" : "Cancel") : "Change"; color: changeBtn.ink }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // ---- the landing page: you, the wallpaper, quick switches, and a door to every page
                                                Component {
                                                    id: overviewC
                                                    Column {
                                                        id: overviewCol
                                                        width: row.inner; spacing: 14
                                                        topPadding: 4; bottomPadding: 6
                                                        Rectangle {
                                                            width: parent.width; height: 128; radius: BarStyle.radiusMedium
                                                            gradient: Gradient {
                                                                orientation: Gradient.Horizontal
                                                                GradientStop { position: 0; color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.28) }
                                                                GradientStop { position: 1; color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.04) }
                                                            }
                                                            border.width: 1; border.color: BarStyle.border
                                                            LockAvatar { x: 22; anchors.verticalCenter: parent.verticalCenter; size: 84 }
                                                            Column {
                                                                x: 128; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                                                BarText { text: "Hello, " + (Config.options?.account?.name || SystemInfo.displayName); font.pixelSize: 24; font.weight: Font.DemiBold }
                                                                BarText { text: DateTime.date + "   ·   up " + DateTime.uptime; color: BarStyle.subtext }
                                                                BarText { visible: Profiles.active !== ""; text: "Profile: " + Profiles.active; color: BarStyle.accent; font.pixelSize: 12 }
                                                            }
                                                            ClippingRectangle {
                                                                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                                                width: 170; height: 96; radius: BarStyle.radiusSmall; color: BarStyle.surface
                                                                Image { anchors.fill: parent; source: WallpaperState.thumbUrl(WallpaperState.current); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 340 }
                                                                TapHandler { onTapped: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "wallpaper", "open"]) }
                                                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                                                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 26; color: Qt.rgba(0, 0, 0, 0.6)
                                                                    BarText { anchors.centerIn: parent; text: "Change wallpaper"; font.pixelSize: 11; color: "white" } }
                                                            }
                                                        }
                                                        Flow {
                                                            width: parent.width; spacing: 8
                                                            Repeater {
                                                                model: [
                                                                    { icon: "music_note", text: "Orbit", on: false, tap: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "music", "open"]) },
                                                                    { icon: "self_improvement", text: "Focus mode", on: BarTools.focusMode, tap: () => BarTools.toggleFocusMode() },
                                                                    { icon: "notifications_off", text: "Do not disturb", on: Notifications.silent, tap: () => Notifications.toggleSilent() },
                                                                    { icon: "bedtime", text: "Night light", on: BarTools.nightLight, tap: () => BarTools.toggleNightLight() },
                                                                    { icon: "coffee", text: "Caffeine", on: BarTools.caffeine, tap: () => BarTools.toggleCaffeine() },
                                                                    { icon: "wifi", text: "Wi-Fi", on: NetLink.iwd ? NetLink.wifiEnabled : Network.wifiEnabled, tap: () => NetLink.iwd ? NetLink.setPowered(!NetLink.wifiEnabled) : Network.toggleWifi() },
                                                                    { icon: "bluetooth", text: "Bluetooth", on: BluetoothStatus.enabled, tap: () => { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled } }
                                                                ]
                                                                delegate: BarButton {
                                                                    id: sq
                                                                    required property var modelData
                                                                    tone: "outlined"; toggled: modelData.on
                                                                    width: sqRow.implicitWidth + 28; height: 40; radius: 20
                                                                    onTapped: sq.modelData.tap()
                                                                    Row {
                                                                        id: sqRow
                                                                        anchors.centerIn: parent; spacing: 8
                                                                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: sq.modelData.icon; size: 18; color: sq.inkSoft }
                                                                        BarText { anchors.verticalCenter: parent.verticalCenter; text: sq.modelData.text; font.weight: Font.Medium; color: sq.ink }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        Flow {
                                                            width: parent.width; spacing: 10
                                                            Repeater {
                                                                model: root.pages.slice(1)
                                                                delegate: BarButton {
                                                                    id: pc
                                                                    required property var modelData
                                                                    required property int index
                                                                    tone: "outlined"
                                                                    width: Math.floor((overviewCol.width - 20) / 3); height: 84; radius: BarStyle.radiusMedium
                                                                    onTapped: root.page = pc.index + 1
                                                                    Rectangle {
                                                                        x: 14; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; radius: 22
                                                                        color: BarStyle.accentContainer
                                                                        BarIcon { anchors.centerIn: parent; name: pc.modelData.icon; size: 22; color: BarStyle.onAccentContainer }
                                                                    }
                                                                    Column {
                                                                        x: 70; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 2
                                                                        BarText { text: pc.modelData.name; font.weight: Font.DemiBold }
                                                                        BarText { width: parent.width; elide: Text.ElideRight; text: pc.modelData.blurb; font.pixelSize: 11; color: BarStyle.subtext }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Footer, pinned: where the settings live, and Reset page (asks first)
                Rectangle {
                    id: footer
                    x: nav.width; y: parent.height - height; width: parent.width - nav.width; height: 56
                    color: BarStyle.surface
                    property bool confirm: false
                    readonly property bool canReset: view.resettable.length > 0
                    Connections { target: root; function onPageChanged() { footer.confirm = false } }
                    Timer { interval: 4000; running: footer.confirm; onTriggered: footer.confirm = false }
                    Rectangle { width: parent.width; height: 1; color: BarStyle.border; opacity: 0.6 }
                    Row {
                        visible: !footer.confirm
                        x: 32; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "folder_open"; size: 18; color: BarStyle.subtext }
                        BarText { anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth + 1, footer.width - 64 - 160); elide: Text.ElideMiddle
                            text: Directories.shellConfigPath; font.pixelSize: 12; color: BarStyle.subtext }
                    }
                    BarText { visible: footer.confirm; x: 32; anchors.verticalCenter: parent.verticalCenter
                        text: "Put everything on this page back to its default?"; color: BarStyle.text }
                    Row {
                        anchors { right: parent.right; rightMargin: 32; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        BarButton {
                            id: cancelBtn
                            visible: footer.confirm
                            tone: "outlined"; width: 76; height: 34; radius: 17
                            onTapped: footer.confirm = false
                            BarText { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: cancelBtn.ink }
                        }
                        BarButton {
                            id: resetBtn
                            visible: footer.canReset
                            tone: footer.confirm ? "filled" : "outlined"; width: footer.confirm ? 76 : 110; height: 34; radius: 17
                            onTapped: { if (footer.confirm) { view.resetPage(); footer.confirm = false } else footer.confirm = true }
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                BarIcon { anchors.verticalCenter: parent.verticalCenter; visible: !footer.confirm; name: "restart_alt"; size: 16; color: resetBtn.ink }
                                BarText { anchors.verticalCenter: parent.verticalCenter; text: footer.confirm ? "Reset" : "Reset page"; font.pixelSize: 12; font.weight: Font.Medium; color: resetBtn.ink }
                            }
                        }
                    }
                }

                // ---- Search results, over the page
                Rectangle {
                    x: nav.width; width: parent.width - nav.width; height: parent.height - footer.height
                    visible: view.searching
                    color: BarStyle.surface
                    BarText {
                        visible: view.results.length === 0
                        x: 32; y: 40; text: "Nothing matches \"" + view.query.trim() + "\""; color: BarStyle.subtext
                    }
                    Flickable {
                        anchors { fill: parent; margins: 20 }
                        contentHeight: resCol.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: resCol
                            width: parent.width; spacing: 2
                            Repeater {
                                model: view.results
                                delegate: Item {
                                    id: res
                                    required property var modelData
                                    required property int index
                                    width: resCol.width; height: 58
                                    readonly property bool sel: view.picked === index
                                    Rectangle { anchors.fill: parent; radius: BarStyle.radiusSmall; color: res.sel ? BarStyle.accentContainer : (resHov.hovered ? BarStyle.plateHover : "transparent") }
                                    Rectangle {
                                        x: 10; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 38; radius: 14
                                        color: res.sel ? BarStyle.accent : BarStyle.cardHigh
                                        BarIcon { anchors.centerIn: parent; name: root.pages[res.modelData.page]?.icon ?? "settings"; size: 20; color: res.sel ? BarStyle.onAccent : BarStyle.subtext }
                                    }
                                    Column {
                                        x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 76; spacing: 1
                                        BarText { width: parent.width; elide: Text.ElideRight; textFormat: Text.StyledText; text: Search.mark(res.modelData.label, view.query, String(BarStyle.accent)); font.weight: Font.DemiBold; color: res.sel ? BarStyle.onAccentContainer : BarStyle.text }
                                        BarText { width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; color: BarStyle.subtext
                                            text: res.modelData.pageName + (res.modelData.group ? "  ›  " + res.modelData.group : "") }
                                    }
                                    HoverHandler { id: resHov; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) view.picked = res.index }
                                    TapHandler { onTapped: view.jump(res.modelData) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
