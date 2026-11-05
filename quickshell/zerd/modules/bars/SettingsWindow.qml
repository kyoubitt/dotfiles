pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.modules.common
import qs.modules.lockScreen
import qs.services

// The shell's settings: a window with pages down the left and plain switches, choices and steppers on the right.
// Every row reads and writes one config path, so changes show at once. `ipc call settings toggle|open|close`.
Scope {
    id: root

    property bool open: false
    property int page: 0
    property string query: ""
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
    onOpenChanged: { GlobalStates.settingsOpen = root.open; if (root.open) { root.query = ""; root.rebinding = ""; NiriBinds.reload(); tzProc.running = true } }
    Connections { target: GlobalStates; function onSettingsOpenChanged() { root.open = GlobalStates.settingsOpen } }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.open = !root.open }
        function open(): void { root.open = true }
        function close(): void { root.open = false }
        function page(name: string): void { const i = root.pages.findIndex(p => p.name.toLowerCase() === name.toLowerCase()); if (i >= 0) { root.page = i; root.open = true } }
    }

    readonly property var blurbs: ({ Profile: "Who you are, and saved set-ups", Bar: "The top bar", Dock: "The app dock", Panels: "The quick panel and the sections panel",
        Launcher: "The app list", Colours: "Wallpaper and colours", Time: "Clock, dates and world clocks", Overview: "Everything in one place", Controls: "Keyboard shortcuts", Notifications: "Banners", Feedback: "Pills and confirmations", Widgets: "The desktop widget board" })
    readonly property var pages: [
        { name: "Overview", icon: "home", rows: [ { t: "overview", label: "" } ] },
        { name: "Profile", icon: "person", rows: [
            { t: "user", label: "You" },
            { t: "profiles", label: "Profiles", hint: "A profile remembers the wallpaper, the colour scheme and the main bar, dock and panel settings" }
        ] },
        { name: "Bar", icon: "toolbar", rows: [
            { t: "toggle", label: "Hide the bar until the pointer is at the top", hint: "Rest the pointer on the top edge to bring it back", path: "bars.top.autoHide", def: false },
            { t: "toggle", label: "Slide away next to a fullscreen window", hint: "Only when a fullscreen and a normal window share the screen", path: "bars.top.smartHide", def: true },
            { t: "choice", label: "Bar style", hint: "Pills: a capsule per group. Strip: one full-width bar. Floating: one rounded bar", path: "bars.top.look", opts: [{ v: "pills", l: "Pills" }, { v: "strip", l: "Strip" }, { v: "floating", l: "Floating" }], def: "pills" },
            { t: "choice", label: "Workspaces", hint: "Icons show the apps open on each workspace", path: "bars.top.workspaceStyle", opts: ["pills", "numbers", "icons"], def: "pills" },
            { t: "step", label: "Tray icons before \"more\"", path: "bars.top.trayMax", min: 2, max: 12, by: 1, def: 6 },
            { t: "step", label: "Bar height", path: "bars.top.height", min: 28, max: 44, by: 2, def: 34 },
            { t: "actions", label: "Layout", hint: "Drag the blocks where you want them, hide what you don't use. Window titles can show private chats, so that block starts hidden", acts: [
                { text: "Edit bar layout", cmd: ["qs", "-c", "zerd", "ipc", "call", "baredit", "open"] },
                { text: "Reset to default", cmd: ["qs", "-c", "zerd", "ipc", "call", "baredit", "reset"] } ] },
        ] },
        { name: "Dock", icon: "dock_to_bottom", rows: [
            { t: "toggle", label: "Hide the dock until the pointer is at the edge", hint: "Rest the pointer on the screen edge to show it", path: "iris.dock.autoHide", def: true },
            { t: "toggle", label: "Attach to the screen edge", hint: "The dock grows out of the bottom edge with curved corners, like a notch", path: "iris.dock.notch", def: false },
            { t: "choice", label: "Style", hint: "Tiles: every icon on its own dark square in a flat plate. Classic: the floating pill", path: "iris.dock.style", opts: ["tiles", "classic"], def: "tiles" },
            { t: "toggle", label: "Spectrum", hint: "Moves with the music while a song plays", path: "iris.dock.cava.enable", def: true },
            { t: "choice", label: "Spectrum style", hint: "Wave: a soft hill along the bottom of the screen. Inside: bars in the dock plate", path: "iris.dock.cava.style", opts: ["wave", "inside"], def: "wave" },
            { t: "step", label: "Icon size", path: "iris.dock.iconSize", min: 28, max: 64, by: 2, def: 40 },
            { t: "toggle", label: "Magnify icons under the pointer", path: "iris.dock.magnification", def: true },
            { t: "toggle", label: "Badges", path: "iris.dock.badges", def: true },
            { t: "toggle", label: "Drag icons to reorder", path: "iris.dock.reorder", def: true }
        ] },
        { name: "Panels", icon: "side_navigation", rows: [
            { t: "toggle", label: "Open a panel from the screen edge", hint: "The pointer has to move onto the edge and rest there", path: "bars.sidebars.edgeHover", def: true },
            { t: "choice", label: "Edges", path: "bars.sidebars.edgeSide", opts: ["left", "right", "both"], def: "both" },
            { t: "toggle", label: "Focus timer turns Do not disturb on", path: "bars.sidebars.focusDnd", def: true }
        ] },
        { name: "Controls", icon: "keyboard", rows: [
            { t: "binds", label: "Keyboard shortcuts", hint: "Click Change, then press the new keys. Keys that are already taken run their own action instead" }
        ] },
        { name: "Time", icon: "schedule", rows: [
            { t: "preview", label: "Right now" },
            { t: "choice", label: "Clock", hint: "Bar, lock screen, clock widgets", path: "time.format", def: "hh:mm",
              opts: [{ v: "hh:mm", l: "24-hour" }, { v: "hh:mm:ss", l: "24-hour, seconds" }, { v: "h:mm AP", l: "12-hour" }, { v: "h:mm:ss AP", l: "12-hour, seconds" }] },
            { t: "choice", label: "Short date", hint: "Next to the clock in the bar. d = day, M = month, y = year", path: "time.shortDateFormat", def: "dd/MM",
              opts: ["dd/MM", "MM/dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "yyyy-MM-dd", "d MMM", "MMM d", "ddd d"].map(f => ({ v: f, l: Qt.formatDateTime(new Date(), f) })) },
            { t: "choice", label: "Long date", hint: "Calendar, widgets and the lock screen", path: "time.dateFormat", def: "ddd, dd/MM",
              opts: ["ddd, dd/MM", "ddd, MM/dd", "ddd, dd/MM/yyyy", "ddd, MM/dd/yyyy", "dddd, d MMMM", "dddd, MMMM d", "dddd, MMMM d, yyyy", "ddd d MMM yyyy", "yyyy-MM-dd"].map(f => ({ v: f, l: Qt.formatDateTime(new Date(), f) })) },
            { t: "choice", label: "Temperature", hint: "Weather in the bar, the weather popup and widgets (Fahrenheit also switches wind to mph)", path: "bar.weather.useUSCS", def: false,
              opts: [{ v: false, l: "Celsius (°C)" }, { v: true, l: "Fahrenheit (°F)" }] },
            { t: "list", label: "World clocks", hint: "Zones for the world clock widget, like Europe/London. Press Enter to add", path: "desktopWidgets.worldClock.timezones", keepCase: true },
            { t: "info", label: "System time zone", hint: "Changing it needs admin rights: timedatectl set-timezone", key: "tzInfo" }
        ] },
        { name: "Launcher", icon: "apps", rows: [
            { t: "list", label: "Hidden from the app list", hint: "Part of an app's name or id. Typing the name still finds it", path: "iris.launcher.hidden" }
        ] },
        { name: "Colours", icon: "palette", rows: [
            { t: "actions", label: "Wallpaper", hint: "The colours of everything come from the wallpaper", acts: [
                { text: "Choose…", cmd: ["qs", "-c", "zerd", "ipc", "call", "wallpaper", "open"] },
                { text: "Random", cmd: ["qs", "-c", "zerd", "ipc", "call", "wallpaper", "random"] } ] },
            { t: "swatches", label: "Accent colour", hint: "Auto takes it from the wallpaper" },
            { t: "choice", label: "Scheme", hint: "Auto follows the system", path: "iris.appearance.scheme", opts: ["auto", "dark", "ink", "light"], def: "auto" },
            { t: "toggle", label: "Colours follow the wallpaper (wallust)", hint: "Off keeps the solver's last palette for the dock, launcher and cards", path: "iris.wallust", def: true },
            { t: "toggle", label: "Dock icons magnify under the pointer", path: "iris.dock.magnification", def: true }
        ] },
        { name: "Notifications", icon: "notifications", rows: [
            { t: "choice", label: "Banners", path: "bars.notifications.engine", opts: ["inir", "waffle"], def: "inir" },
            { t: "choice", label: "Position", path: "bars.notifications.position", opts: ["top", "bottom"], def: "top" },
            { t: "step", label: "Width", path: "bars.notifications.width", min: 300, max: 520, by: 20, def: 380 }
        ] },
        { name: "Feedback", icon: "volume_up", rows: [
            { t: "toggle", label: "Volume and brightness pill", path: "bars.osd.enable", def: true },
            { t: "choice", label: "Pill position", path: "bars.osd.position", opts: ["bottom", "top"], def: "bottom" },
            { t: "step", label: "Pill time (ms)", path: "bars.osd.timeout", min: 800, max: 4000, by: 100, def: 1500 },
            { t: "toggle", label: "Ask before closing important apps", hint: "Mod+Q closes at once when this is off", path: "closeConfirm.enabled", def: false }
        ] },
        { name: "Widgets", icon: "widgets", rows: [
            { t: "cards", label: "Desktop widgets", hint: "Tap to show or hide one. They sit on the wallpaper, under your windows" },
            { t: "actions", label: "Arrange", hint: "Drag them where you want them", acts: [
                { text: "Arrange on screen", cmd: ["qs", "-c", "zerd", "ipc", "call", "widgetboard", "toggle"] },
                { text: "Show all", cmd: ["qs", "-c", "zerd", "ipc", "call", "widgets", "toggleAll"] } ] },
            { t: "choice", label: "Board grid (px, 0 = off)", path: "bars.board.grid", opts: [0, 8, 16, 32, 64], def: 32 },
            { t: "toggle", label: "Snap to the grid", path: "bars.board.snap", def: true },
            { t: "toggle", label: "Draw the grid", path: "bars.board.showGrid", def: true }
        ] }
    ]

    // With something typed in the search box, every row of every page that matches.
    readonly property var shownRows: {
        const q = root.query.trim().toLowerCase()
        if (q.length === 0) return root.pages[root.page].rows
        const out = []
        for (const pg of root.pages) for (const r of pg.rows) if ((r.label + " " + (r.hint ?? "") + " " + pg.name).toLowerCase().includes(q)) out.push(Object.assign({ where: pg.name }, r))
        return out
    }

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

            // ---- Pages
            Rectangle {
                id: nav
                x: 0; y: 0; width: 210; height: win.height
                color: Qt.darker(BarStyle.surface, 1.25)
                Column {
                    x: 12; y: 18; width: parent.width - 24; spacing: 4
                    Row {
                        x: 8; spacing: 10; bottomPadding: 12
                        LockAvatar { size: 40 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            BarText { text: Config.options?.account?.name || SystemInfo.displayName; font.pixelSize: 15; font.weight: Font.DemiBold }
                            BarText { text: Profiles.active !== "" ? Profiles.active : "Settings"; font.pixelSize: 11; color: BarStyle.subtext }
                        }
                    }
                    Repeater {
                        model: root.pages
                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            required property int index
                            width: parent.width; height: 42; radius: 21
                            color: root.page === index ? BarStyle.accentContainer : (hov.hovered ? BarStyle.plateHover : "transparent")
                            Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
                            Rectangle {
                                x: 0; anchors.verticalCenter: parent.verticalCenter
                                width: 4; height: root.page === item.index ? 20 : 0; radius: 2
                                color: BarStyle.accent
                                Behavior on height { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutBack } }
                            }
                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 10
                                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: item.modelData.icon; size: 20; color: root.page === item.index ? BarStyle.onAccentContainer : BarStyle.subtext }
                                BarText { anchors.verticalCenter: parent.verticalCenter; text: item.modelData.name; font.weight: root.page === item.index ? Font.DemiBold : Font.Medium; color: root.page === item.index ? BarStyle.onAccentContainer : BarStyle.text }
                            }
                            HoverHandler { id: hov }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = item.index }
                        }
                    }
                }
            }

            // ---- Rows
            Flickable {
                x: nav.width; width: win.width - nav.width; height: win.height
                contentHeight: rows.implicitHeight + 56
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: rows
                    x: 32; y: 28; width: parent.width - 64; spacing: 14
                    Connections { target: root; function onPageChanged() { rise.restart() } }
                    ParallelAnimation {
                        id: rise
                        NumberAnimation { target: rows; property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutCubic }
                        NumberAnimation { target: rows; property: "y"; from: 38; to: 28; duration: 130; easing.type: Easing.OutCubic }
                    }
                    Item {
                        width: rows.width; height: 44
                        Rectangle {
                            id: badge
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44; radius: 16
                            color: BarStyle.accentContainer
                            BarIcon { anchors.centerIn: parent; name: root.query.length > 0 ? "search" : root.pages[root.page].icon; size: 24; fill: 1; color: BarStyle.onAccentContainer }
                        }
                        Column {
                            x: badge.width + 14
                            anchors.verticalCenter: parent.verticalCenter
                            BarText { text: root.query.length > 0 ? "Search" : root.pages[root.page].name; font.pixelSize: 24; font.weight: Font.DemiBold }
                            BarText { text: root.query.length > 0 ? "Every page" : (root.blurbs[root.pages[root.page].name] ?? ""); font.pixelSize: 12; color: BarStyle.subtext }
                        }
                        Rectangle {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 230; height: 36; radius: 18
                            color: BarStyle.plate; border.width: 1; border.color: searchIn.activeFocus ? BarStyle.accent : BarStyle.border
                            BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: BarStyle.subtext }
                            TextInput {
                                id: searchIn
                                x: 38; width: parent.width - 50; anchors.verticalCenter: parent.verticalCenter
                                color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                                text: root.query
                                onTextChanged: root.query = text
                                Keys.onEscapePressed: { if (text.length > 0) text = ""; else root.open = false }
                            }
                            BarText { x: 38; anchors.verticalCenter: parent.verticalCenter; visible: searchIn.text.length === 0; text: "Search settings"; color: BarStyle.subtext }
                        }
                    }
                    Item {
                      width: rows.width; height: cardCol.implicitHeight
                      Rectangle {
                          anchors.fill: parent; radius: 24; color: BarStyle.plate; border.width: 1; border.color: BarStyle.border
                          gradient: Gradient {
                              GradientStop { position: 0.0; color: Qt.tint(BarStyle.plate, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.07)) }
                              GradientStop { position: 0.35; color: BarStyle.plate }
                          }
                      }
                      Column {
                        id: cardCol
                        width: parent.width
                    Repeater {
                        id: rowRep
                        model: root.shownRows
                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            // long lists of choices (the date formats) wrap under the label instead of running off the card
                            readonly property bool wrap: modelData.t === "choice" && (modelData.opts?.length ?? 0) > 5
                            // buttons with a long hint sit under the text, never under the words
                            readonly property bool stack: modelData.t === "actions" && (modelData.hint?.length ?? 0) > 46
                            readonly property bool block: row.wrap || row.stack || ["list", "profiles", "binds", "cards", "swatches", "overview"].includes(modelData.t)
                            readonly property var value: Config.getNestedValue(modelData.path, modelData.def)
                            width: cardCol.width; height: row.modelData.t === "overview" ? overviewCol.implicitHeight + 28 : row.modelData.t === "preview" ? 96 : row.modelData.t === "list" ? hiddenCol.implicitHeight + 76 : row.modelData.t === "binds" ? bindsCol.implicitHeight + 74 : row.modelData.t === "cards" ? cardsFlow.implicitHeight + 78 : row.modelData.t === "swatches" ? 112 : row.modelData.t === "user" ? 118 : row.modelData.t === "profiles" ? profCol.implicitHeight + 76 : row.wrap ? labelCol.height + wrapRow.height + 42 : row.stack ? labelCol.height + 30 + 44 : (row.modelData.hint || row.modelData.where ? 64 : 54)
                            Rectangle { visible: row.index < rowRep.count - 1; anchors.bottom: parent.bottom; x: 18; width: parent.width - 36; height: 1; color: BarStyle.border; opacity: 0.7 }
                            Column {
                                id: labelCol
                                x: 18; y: row.block ? 14 : Math.round((parent.height - height) / 2)
                                visible: row.modelData.t !== "user"
                                width: row.block ? parent.width - 36 : (row.modelData.t === "choice" ? Math.max(120, parent.width - chipsRow.width - 64) : parent.width - 260)
                                spacing: 2
                                BarText { width: parent.width; elide: Text.ElideRight; text: row.modelData.label }
                                BarText { visible: text.length > 0; width: parent.width; elide: Text.ElideRight; wrapMode: row.block ? Text.WordWrap : Text.NoWrap; maximumLineCount: row.block ? 2 : 1; font.pixelSize: 12; color: BarStyle.subtext
                                    text: (row.modelData.where ? row.modelData.where + (row.modelData.hint ? "  ·  " : "") : "") + (row.modelData.hint ?? "") }
                            }
                            // the person: picture, name, and buttons to change them
                            Item {
                                visible: row.modelData.t === "user"
                                anchors.fill: parent
                                LockAvatar { x: 20; anchors.verticalCenter: parent.verticalCenter; size: 78 }
                                Rectangle {
                                    x: 120; y: 24; width: 280; height: 36; radius: 18
                                    color: BarStyle.surface; border.width: 1; border.color: nameIn.activeFocus ? BarStyle.accent : BarStyle.border
                                    TextInput {
                                        id: nameIn
                                        x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter
                                        color: BarStyle.text; font.pixelSize: 16; font.weight: Font.DemiBold; clip: true
                                        text: Config.options?.account?.name || SystemInfo.displayName
                                        onEditingFinished: Config.setNestedValue("account.name", text.trim())
                                    }
                                }
                                Row {
                                    x: 120; y: 70; spacing: 8
                                    Repeater {
                                        model: [{ text: "Change picture…", a: "pick" }, { text: "Remove picture", a: "clear" }]
                                        delegate: Rectangle {
                                            id: ub
                                            required property var modelData
                                            width: ubText.implicitWidth + 28; height: 30; radius: 15
                                            color: ubHov.hovered ? BarStyle.plateHover : "transparent"; border.width: 1; border.color: BarStyle.border
                                            BarText { id: ubText; anchors.centerIn: parent; text: ub.modelData.text; font.pixelSize: 12 }
                                            HoverHandler { id: ubHov }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (ub.modelData.a === "pick") picker.running = true; else Config.setNestedValue("account.avatar", "") } }
                                        }
                                    }
                                }
                                Process {
                                    id: picker
                                    command: ["zenity", "--file-selection", "--title=Profile picture", "--file-filter=Images | *.png *.jpg *.jpeg *.webp", "--filename=" + Quickshell.env("HOME") + "/Pictures/"]
                                    stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f.length > 0) Config.setNestedValue("account.avatar", f) } }
                                }
                            }
                            // saved set-ups
                            Column {
                                id: profCol
                                visible: row.modelData.t === "profiles"
                                x: 18; y: 62; width: parent.width - 36; spacing: 6
                                Repeater {
                                    model: Profiles.list
                                    delegate: Rectangle {
                                        id: prof
                                        required property var modelData
                                        readonly property bool on: Profiles.active === modelData.name
                                        width: profCol.width; height: 46; radius: 14
                                        color: on ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.18) : "transparent"
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
                                            Rectangle {
                                                width: 64; height: 30; radius: 15; color: apHov.hovered ? BarStyle.plateHover : BarStyle.accent
                                                BarText { anchors.centerIn: parent; text: prof.on ? "Active" : "Apply"; font.pixelSize: 12; color: BarStyle.onAccent }
                                                HoverHandler { id: apHov }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.apply(prof.modelData.name) }
                                            }
                                            Rectangle {
                                                width: 30; height: 30; radius: 15; color: dlHov.hovered ? BarStyle.plateHover : "transparent"
                                                BarIcon { anchors.centerIn: parent; name: "delete"; size: 17; color: BarStyle.subtext }
                                                HoverHandler { id: dlHov }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Profiles.remove(prof.modelData.name) }
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
                                            onAccepted: { Profiles.capture(text); text = "" }
                                        }
                                        BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: profIn.text.length === 0; text: "Name for the current set-up"; color: BarStyle.subtext; font.pixelSize: 12 }
                                    }
                                    Rectangle {
                                        width: 70; height: 34; radius: 17; color: svHov.hovered ? BarStyle.plateHover : BarStyle.accent
                                        BarText { anchors.centerIn: parent; text: "Save"; font.pixelSize: 12; font.weight: Font.DemiBold; color: BarStyle.onAccent }
                                        HoverHandler { id: svHov }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Profiles.capture(profIn.text); profIn.text = "" } }
                                    }
                                }
                            }
                            // buttons that run something
                            Row {
                                visible: row.modelData.t === "actions"
                                x: row.stack ? 18 : row.width - width - 14
                                y: row.stack ? labelCol.y + labelCol.height + 12 : Math.round((row.height - height) / 2)
                                spacing: 6
                                Repeater {
                                    model: row.modelData.acts ?? []
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
                            // the time as it will read
                            Column {
                                visible: row.modelData.t === "preview"
                                anchors.centerIn: parent
                                spacing: 2
                                BarText { anchors.horizontalCenter: parent.horizontalCenter; text: DateTime.time; font.pixelSize: 40; font.weight: Font.DemiBold }
                                BarText { anchors.horizontalCenter: parent.horizontalCenter; text: DateTime.date + "   ·   " + DateTime.shortDate; color: BarStyle.subtext }
                            }
                            // read-only value on the right
                            BarText {
                                visible: row.modelData.t === "info"
                                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                                text: root[row.modelData.key ?? ""] ?? ""
                                color: BarStyle.accent; font.weight: Font.Medium
                            }
                            // the landing page: you, the wallpaper, quick switches, and a door to every page
                            Column {
                                id: overviewCol
                                visible: row.modelData.t === "overview"
                                x: 14; y: 14; width: parent.width - 28; spacing: 14
                                Rectangle {
                                    width: parent.width; height: 128; radius: BarStyle.radiusLarge
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
                                    // the wallpaper in use
                                    Rectangle {
                                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                        width: 170; height: 96; radius: BarStyle.radiusMedium; color: BarStyle.surface; clip: true
                                        Image { anchors.fill: parent; source: WallpaperState.thumbUrl(WallpaperState.current); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 340 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "wallpaper", "open"]) }
                                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 26; color: "#99000000"
                                            BarText { anchors.centerIn: parent; text: "Change wallpaper"; font.pixelSize: 11; color: "white" } }
                                    }
                                }
                                // switches
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
                                        delegate: Rectangle {
                                            id: sq
                                            required property var modelData
                                            width: sqRow.implicitWidth + 28; height: 40; radius: 20
                                            color: modelData.on ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.24) : (sqHov.hovered ? BarStyle.plateHover : "transparent")
                                            border.width: 1; border.color: modelData.on ? BarStyle.accent : BarStyle.border
                                            Behavior on color { ColorAnimation { duration: 90 } }
                                            Row {
                                                id: sqRow
                                                anchors.centerIn: parent; spacing: 8
                                                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: sq.modelData.icon; size: 18; color: sq.modelData.on ? BarStyle.accent : BarStyle.subtext }
                                                BarText { anchors.verticalCenter: parent.verticalCenter; text: sq.modelData.text; font.weight: Font.Medium }
                                            }
                                            HoverHandler { id: sqHov }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sq.modelData.tap() }
                                        }
                                    }
                                }
                                // a card for every page
                                Flow {
                                    width: parent.width; spacing: 10
                                    Repeater {
                                        model: root.pages.slice(1)
                                        delegate: Rectangle {
                                            id: pc
                                            required property var modelData
                                            required property int index
                                            width: Math.floor((overviewCol.width - 20) / 3); height: 84; radius: BarStyle.radiusMedium
                                            color: pcHov.hovered ? BarStyle.plateHover : "transparent"
                                            border.width: 1; border.color: BarStyle.border
                                            Behavior on color { ColorAnimation { duration: 90 } }
                                            Rectangle {
                                                x: 14; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; radius: 22
                                                color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.2)
                                                BarIcon { anchors.centerIn: parent; name: pc.modelData.icon; size: 22; color: BarStyle.accent }
                                            }
                                            Column {
                                                x: 70; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; spacing: 2
                                                BarText { text: pc.modelData.name; font.weight: Font.DemiBold }
                                                BarText { width: parent.width; elide: Text.ElideRight; text: root.blurbs[pc.modelData.name] ?? ""; font.pixelSize: 11; color: BarStyle.subtext }
                                            }
                                            HoverHandler { id: pcHov }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page = pc.index + 1 }
                                        }
                                    }
                                }
                            }
                            // every keyboard shortcut, with a button to change each
                            Column {
                                id: bindsCol
                                visible: row.modelData.t === "binds"
                                x: 18; y: 62; width: parent.width - 36; spacing: 2
                                Text { visible: NiriBinds.message.length > 0; text: NiriBinds.message; color: NiriBinds.message === "Changed" ? BarStyle.accent : BarStyle.danger; font.pixelSize: 12; bottomPadding: 6 }
                                Repeater {
                                    model: NiriBinds.list.filter(b => {
                                        const q = root.query.trim().toLowerCase()
                                        return q.length === 0 || (NiriBinds.nameOf(b) + " " + b.key + " " + b.action).toLowerCase().includes(q)
                                    })
                                    delegate: Item {
                                        id: bind
                                        required property var modelData
                                        readonly property bool editing: root.rebinding === modelData.key
                                        width: bindsCol.width; height: 44
                                        Rectangle { anchors.fill: parent; radius: 14; color: bindHov.hovered || bind.editing ? BarStyle.plateHover : "transparent"; Behavior on color { ColorAnimation { duration: 90 } } }
                                        HoverHandler { id: bindHov }
                                        BarText { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 320; elide: Text.ElideRight; text: NiriBinds.nameOf(bind.modelData) }
                                        // the keys as caps
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
                                        // waiting for the new keys
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
                                        Rectangle {
                                            id: changeBtn
                                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                            width: 76; height: 30; radius: 15
                                            color: bind.editing && capture.combo.length > 0 ? BarStyle.accent : (chHov.hovered ? BarStyle.plateHover : "transparent")
                                            border.width: 1; border.color: bind.editing && capture.combo.length > 0 ? BarStyle.accent : BarStyle.border
                                            BarText { anchors.centerIn: parent; font.pixelSize: 12; text: bind.editing ? (capture.combo.length > 0 ? "Save" : "Cancel") : "Change"
                                                color: bind.editing && capture.combo.length > 0 ? BarStyle.onAccent : BarStyle.text }
                                            HoverHandler { id: chHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!bind.editing) { NiriBinds.message = ""; root.rebinding = bind.modelData.key }
                                                    else if (capture.combo.length > 0) { NiriBinds.rebind(bind.modelData.key, capture.combo); root.rebinding = "" }
                                                    else root.rebinding = ""
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // desktop widgets: a tile for each
                            Flow {
                                id: cardsFlow
                                visible: row.modelData.t === "cards"
                                x: 18; y: 62; width: parent.width - 36; spacing: 8
                                Repeater {
                                    model: WidgetRegistry.cards
                                    delegate: Rectangle {
                                        id: tile
                                        required property var modelData
                                        readonly property bool on: Config.getNestedValue("desktopWidgets." + modelData.name + ".enable", false)
                                        width: tileRow.implicitWidth + 26; height: 38; radius: 19
                                        color: on ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.22) : (tHov.hovered ? BarStyle.plateHover : "transparent")
                                        border.width: 1; border.color: on ? BarStyle.accent : BarStyle.border
                                        Behavior on color { ColorAnimation { duration: 90 } }
                                        Row {
                                            id: tileRow
                                            anchors.centerIn: parent; spacing: 7
                                            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: tile.on ? "check" : tile.modelData.icon; size: 17; color: tile.on ? BarStyle.accent : BarStyle.subtext }
                                            BarText { anchors.verticalCenter: parent.verticalCenter; text: tile.modelData.title; font.pixelSize: 12; font.weight: Font.Medium }
                                        }
                                        HoverHandler { id: tHov }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Config.setNestedValue("desktopWidgets." + tile.modelData.name + ".enable", !tile.on) }
                                    }
                                }
                            }
                            // accent colours: the wallpaper's, then a few fixed ones
                            Row {
                                visible: row.modelData.t === "swatches"
                                x: 18; y: 66; spacing: 10
                                Repeater {
                                    model: [{ hex: "", label: "Auto" }].concat(["#ef5350", "#ff7043", "#ffca28", "#66bb6a", "#26a69a", "#42a5f5", "#7e57c2", "#ec407a", "#bdbdbd"].map(h => ({ hex: h, label: h })))
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
                                        HoverHandler { id: swHov }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Config.setNestedValue("colours.accent", sw.modelData.hex) }
                                    }
                                }
                            }
                            // a list of words: each one with a remove button, and a field to add
                            Column {
                                id: hiddenCol
                                visible: row.modelData.t === "list"
                                x: 18; y: 56; width: parent.width - 36; spacing: 8
                                Flow {
                                    width: parent.width; spacing: 6
                                    Repeater {
                                        model: Config.getNestedValue(row.modelData.path, [])
                                        delegate: Rectangle {
                                            id: tag
                                            required property var modelData
                                            height: 28; radius: 14; width: tagText.implicitWidth + 40
                                            color: BarStyle.plateHover
                                            BarText { id: tagText; x: 12; anchors.verticalCenter: parent.verticalCenter; text: String(tag.modelData); font.pixelSize: 12 }
                                            BarIcon { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } name: "close"; size: 14; color: BarStyle.subtext }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: Config.setNestedValue(row.modelData.path, Config.getNestedValue(row.modelData.path, []).filter(w => w !== tag.modelData)) }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 240; height: 32; radius: 16; color: BarStyle.surface; border.width: 1; border.color: addIn.activeFocus ? BarStyle.accent : BarStyle.border
                                    TextInput {
                                        id: addIn
                                        x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                                        color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                                        onAccepted: { const w = row.modelData.keepCase ? text.trim() : text.trim().toLowerCase(); if (w.length > 0) Config.setNestedValue(row.modelData.path, Config.getNestedValue(row.modelData.path, []).concat([w])); text = "" }
                                    }
                                    BarText { x: 14; anchors.verticalCenter: parent.verticalCenter; visible: addIn.text.length === 0; text: "Add a name, then Enter"; color: BarStyle.subtext; font.pixelSize: 12 }
                                }
                            }

                            // switch (Material 3: outlined track when off, the knob grows and shows a tick when on)
                            BarSwitch {
                                visible: row.modelData.t === "toggle"
                                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                checked: !!row.value
                                onToggled: Config.setNestedValue(row.modelData.path, !row.value)
                            }
                            // choice chips
                            Rectangle {
                                visible: row.modelData.t === "choice" && !row.wrap
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                width: chipsRow.width + 8; height: 38; radius: 19; color: BarStyle.surface
                            }
                            // choice chips: one row for a few choices, wrapped under the label for many
                            Component {
                                id: chipC
                                BarButton {
                                    id: chip
                                    required property var modelData
                                    readonly property var v: typeof modelData === "object" ? modelData.v : modelData
                                    readonly property bool on: row.value === v
                                    tone: row.wrap ? "outlined" : "plain"
                                    toggled: on
                                    width: chipText.implicitWidth + 24; height: 32; radius: 16
                                    onTapped: Config.setNestedValue(row.modelData.path, chip.v)
                                    BarText { id: chipText; anchors.centerIn: parent; text: typeof chip.modelData === "object" ? chip.modelData.l : String(chip.modelData); color: chip.ink; font.weight: chip.on ? Font.DemiBold : Font.Medium }
                                }
                            }
                            Row {
                                id: chipsRow
                                visible: row.modelData.t === "choice" && !row.wrap
                                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Repeater { model: row.wrap ? [] : (row.modelData.opts ?? []); delegate: chipC }
                            }
                            Flow {
                                id: wrapRow
                                visible: row.wrap
                                x: 18; y: labelCol.y + labelCol.height + 12
                                width: row.width - 36
                                spacing: 6
                                Repeater { model: row.wrap ? (row.modelData.opts ?? []) : []; delegate: chipC }
                            }
                            // stepper
                            Row {
                                visible: row.modelData.t === "step"
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 6
                                BarButton {
                                    tone: "outlined"; width: 32; height: 32; radius: 16
                                    onTapped: Config.setNestedValue(row.modelData.path, Math.max(row.modelData.min, Number(row.value) - row.modelData.by))
                                    BarIcon { anchors.centerIn: parent; name: "remove"; size: 18; color: BarStyle.text }
                                }
                                BarText { width: 52; horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter; text: String(row.value); font.weight: Font.DemiBold }
                                BarButton {
                                    tone: "outlined"; width: 32; height: 32; radius: 16
                                    onTapped: Config.setNestedValue(row.modelData.path, Math.min(row.modelData.max, Number(row.value) + row.modelData.by))
                                    BarIcon { anchors.centerIn: parent; name: "add"; size: 18; color: BarStyle.text }
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
