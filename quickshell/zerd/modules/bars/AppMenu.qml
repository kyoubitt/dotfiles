pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.dock

// The app menu: a search pill, category chips, the apps you opened last, then every app as a grid (or a list).
// Typing filters, arrows move, Enter opens, Esc closes; right-click pins an app to the dock; sums and system
// actions (lock, sleep, ...) show up when you type them.
Item {
    id: root

    signal closed()
    function close(): void { fade.to = 0; fade.restart(); closeTimer.restart() }
    Timer { id: closeTimer; interval: 130; onTriggered: root.closed() }

    implicitWidth: 720
    implicitHeight: 660
    width: implicitWidth
    height: implicitHeight

    property string query: ""
    property string category: "all"
    property string viewMode: "grid"
    property int current: 0

    opacity: 0
    scale: 0.97
    Component.onCompleted: { fade.to = 1; fade.start(); input.forceActiveFocus() }
    NumberAnimation { id: fade; target: root; property: "opacity"; duration: 130 }
    Behavior on scale { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutCubic } }
    onOpacityChanged: scale = opacity > 0.5 ? 1 : 0.97

    readonly property var categories: [
        { id: "all", label: "All", icon: "apps", match: [] },
        { id: "games", label: "Games", icon: "sports_esports", match: ["Game"] },
        { id: "net", label: "Internet", icon: "language", match: ["Network", "WebBrowser", "InstantMessaging", "Chat", "Email"] },
        { id: "media", label: "Media", icon: "perm_media", match: ["AudioVideo", "Audio", "Video", "Graphics", "Music", "Player"] },
        { id: "dev", label: "Dev", icon: "terminal", match: ["Development", "TerminalEmulator", "IDE"] },
        { id: "sys", label: "System", icon: "settings", match: ["System", "Settings", "Utility", "PackageManager"] }
    ]
    function keyOf(e): string { return String(e?.id ?? "").replace(/\.desktop$/, "") }
    function isPinned(e): bool {
        const k = root.keyOf(e).toLowerCase()
        return IrisDockOrder.pins.some(p => String(p).toLowerCase() === k)
    }
    function inCategory(e, cat): bool {
        if (cat === "all") return true
        const want = root.categories.find(c => c.id === cat)?.match ?? []
        const have = e.categories ?? []
        return want.some(w => have.includes(w))
    }

    // ---- what the menu shows
    readonly property var recentIds: Config.options?.iris?.launcher?.recent ?? []
    readonly property var recentApps: {
        const all = DesktopEntries.applications.values
        const out = []
        for (const e of all) if (!e.noDisplay && root.isPinned(e) && !out.includes(e)) out.push(e)
        for (const id of root.recentIds) {
            const e = all.find(a => String(a.id) === String(id))
            if (e && !e.noDisplay && !out.includes(e)) out.push(e)
        }
        return out.slice(0, 8)
    }
    property string debounced: ""
    Timer { id: deb; interval: 70; onTriggered: root.debounced = root.query.trim() }
    onQueryChanged: { deb.restart(); root.current = 0; LauncherSearch.query = root.query }

    function ipc(target: string, fn: string): void { Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", target, fn]) }
    readonly property var actions: [
        { title: "Lock screen", icon: "lock", keys: ["lock"], run: () => root.ipc("lockScreen", "lock") },
        { title: "Sleep", icon: "bedtime", keys: ["suspend", "sleep"], run: () => Quickshell.execDetached(["sh", "-c", "sleep 1; systemctl suspend"]) },
        { title: "Restart", icon: "restart_alt", keys: ["reboot", "restart"], run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { title: "Shut down", icon: "power_settings_new", keys: ["poweroff", "shutdown"], run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { title: "Choose wallpaper", icon: "wallpaper", keys: ["wallpaper", "background"], run: () => root.ipc("wallpaper", "toggle") },
        { title: "Desktop widgets", icon: "widgets", keys: ["widgets"], run: () => root.ipc("widgets", "toggleAll") },
        { title: "Do not disturb", icon: "notifications_off", keys: ["dnd", "silent"], run: () => Notifications.toggleSilent() },
        { title: "Screenshot", icon: "screenshot_region", keys: ["screenshot"], run: () => Quickshell.execDetached(["niri", "msg", "action", "screenshot"]) },
        { title: "Edit the bar", icon: "tune", keys: ["bar", "edit"], run: () => root.ipc("baredit", "open") }
    ]

    readonly property bool isSum: LauncherSearch.mathResult !== "" && root.debounced.length > 0
    readonly property var items: {
        const q = root.debounced.toLowerCase()
        const hide = (Config.options?.iris?.launcher?.hidden ?? []).map(h => String(h).toLowerCase())
        let apps
        if (q.length > 0) apps = AppSearch.fuzzyQuery(q).filter(e => !e.noDisplay)
        else apps = DesktopEntries.applications.values.filter(e => !e.noDisplay
            && (root.isPinned(e) || !hide.some(h => String(e.name ?? "").toLowerCase().includes(h) || String(e.id ?? "").toLowerCase().includes(h)))
            && root.inCategory(e, root.category))
        const out = []
        if (q.length > 0) {
            for (const a of root.actions) if (a.title.toLowerCase().includes(q) || a.keys.some(k => k.startsWith(q))) out.push({ action: a })
        } else {
            apps = apps.slice().sort((a, b) => {
                const pa = root.isPinned(a), pb = root.isPinned(b)
                if (pa !== pb) return pa ? -1 : 1
                return String(a.name ?? "").localeCompare(String(b.name ?? ""))
            })
        }
        for (const e of apps) out.push({ entry: e })
        if (q.length > 1 && !root.isSum) out.push({ action: { title: "Search the web for \"" + root.debounced + "\"", icon: "travel_explore", keys: [], run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(root.debounced)]) } })
        return out
    }

    function launch(it): void {
        if (!it) return
        if (it.action) { root.close(); it.action.run(); return }
        const e = it.entry
        const id = String(e?.id ?? "").toLowerCase()
        root.close()
        if (id === "orbit" || id === "orbit.desktop") GlobalStates.musicRequest++
        else e.execute()
        try {
            const sid = String(e.id)
            const next = [sid].concat(root.recentIds.filter(x => String(x) !== sid)).slice(0, 6)
            Config.setNestedValue("iris.launcher.recent", next)
        } catch (err) { console.log("[menu] recent failed: " + err) }
    }
    function launchRecent(e): void { root.launch({ entry: e }) }
    function move(d: int): void { root.current = Math.max(0, Math.min(root.items.length - 1, root.current + d)) }

    // ---- surface
    Rectangle {
        anchors.fill: parent
        radius: BarStyle.radiusXL
        color: BarStyle.surface
        border.width: 1
        border.color: BarStyle.edge
        antialiasing: true
    }

    // ---- search pill + view switch
    Rectangle {
        id: pill
        x: 16; y: 16
        width: parent.width - 32 - 96
        height: 52
        radius: 26
        color: BarStyle.card
        border.width: 2
        border.color: input.activeFocus ? BarStyle.accent : "transparent"
        Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
        BarIcon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 22; color: BarStyle.subtext }
        TextInput {
            id: input
            x: 52
            width: parent.width - 52 - 52
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            color: BarStyle.text
            selectionColor: BarStyle.accent
            selectedTextColor: BarStyle.onAccent
            font.family: Appearance.font.family.expressive
            font.pixelSize: 17
            renderType: Text.QtRendering
            clip: true
            onTextChanged: root.query = text
            Keys.onEscapePressed: root.close()
            Keys.onReturnPressed: { if (root.isSum) mathCard.copy(); else root.launch(root.items[root.current]) }
            Keys.onEnterPressed: { if (root.isSum) mathCard.copy(); else root.launch(root.items[root.current]) }
            Keys.onDownPressed: root.move(root.viewMode === "grid" ? 5 : 1)
            Keys.onUpPressed: root.move(root.viewMode === "grid" ? -5 : -1)
            Keys.onRightPressed: event => { if (input.cursorPosition >= input.length) root.move(1); else event.accepted = false }
            Keys.onLeftPressed: event => { if (input.cursorPosition === 0) root.move(-1); else event.accepted = false }
            BarText { visible: input.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Search apps, or type a sum"; color: BarStyle.subtext; font.pixelSize: 17 }
        }
        BarButton {
            visible: input.text.length > 0
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18; tone: "plain"
            onTapped: { input.text = ""; input.forceActiveFocus() }
            BarIcon { anchors.centerIn: parent; name: "close"; size: 18; color: parent.parent.ink }
        }
    }
    Rectangle {
        x: pill.x + pill.width + 8; y: 16
        width: 88; height: 52; radius: 26
        color: BarStyle.card
        Row {
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [{ mode: "grid", icon: "grid_view" }, { mode: "list", icon: "view_list" }]
                delegate: BarButton {
                    id: vb
                    required property var modelData
                    width: 38; height: 38; radius: 19
                    tone: root.viewMode === modelData.mode ? "filled" : "plain"
                    onTapped: root.viewMode = modelData.mode
                    BarIcon { anchors.centerIn: parent; name: vb.modelData.icon; size: 20; color: vb.ink }
                }
            }
        }
    }

    // ---- categories
    Row {
        id: cats
        x: 16; y: 76
        height: 36
        spacing: 8
        visible: root.debounced.length === 0
        Repeater {
            model: root.categories
            delegate: BarButton {
                id: cb
                required property var modelData
                height: 36; width: lab.width + 20 + 22 + 8 + 8
                radius: 18
                tone: "tonal"
                toggled: root.category === modelData.id
                onTapped: { root.category = modelData.id; root.current = 0 }
                BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: cb.modelData.icon; size: 18; color: cb.ink }
                BarText { id: lab; x: 38; anchors.verticalCenter: parent.verticalCenter; text: cb.modelData.label; color: cb.ink; font.pixelSize: 13 }
            }
        }
    }

    // ---- sum card
    Rectangle {
        id: mathCard
        visible: root.isSum
        x: 16; y: 80
        width: parent.width - 32; height: 92
        radius: BarStyle.radiusLarge
        color: BarStyle.accentContainer
        property bool copied: false
        readonly property string plain: String(LauncherSearch.mathResult).replace(/−/g, "-")
        function copy(): void {
            Quickshell.clipboardText = mathCard.plain
            mathCard.copied = true
            Qt.callLater(() => root.close())
        }
        BarText { x: 22; y: 12; width: parent.width - 150; text: root.debounced.replace(/^=/, ""); color: BarStyle.onAccentContainer; opacity: 0.7; font.pixelSize: 13; elide: Text.ElideRight }
        BarText { x: 22; y: 36; width: parent.width - 150; text: "= " + mathCard.plain; color: BarStyle.onAccentContainer; font.pixelSize: 30; font.weight: Font.Bold; elide: Text.ElideRight }
        BarButton {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            width: 100; height: 40; radius: 20; tone: "filled"
            onTapped: mathCard.copy()
            BarIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: mathCard.copied ? "check" : "content_copy"; size: 18; color: parent.parent.ink }
            BarText { x: 40; anchors.verticalCenter: parent.verticalCenter; text: mathCard.copied ? "Copied" : "Copy"; color: parent.parent.ink; font.pixelSize: 13 }
        }
    }

    // ---- recent
    Item {
        id: recent
        x: 16; y: 124
        width: parent.width - 32
        height: visible ? 110 : 0
        visible: root.debounced.length === 0 && root.category === "all" && root.recentApps.length > 0
        BarText { x: 6; text: "Pinned and recent"; color: BarStyle.subtext; font.pixelSize: 12 }
        Row {
            y: 22
            spacing: 10
            Repeater {
                model: root.recentApps
                delegate: BarButton {
                    id: rc
                    required property var modelData
                    width: 64; height: 64; radius: BarStyle.radiusLarge
                    onTapped: root.launchRecent(rc.modelData)
                    Image {
                        anchors.centerIn: parent
                        width: 40; height: 40
                        source: AppSearch.getIconSource(rc.modelData.icon || rc.modelData.name, "application-x-executable")
                        sourceSize: Qt.size(96, 96)
                        smooth: true; mipmap: true; asynchronous: true
                    }
                    BarIcon { visible: root.isPinned(rc.modelData); x: rc.width - 20; y: 5; name: "keep"; fill: 1; size: 13; color: BarStyle.accent }
                }
            }
        }
    }

    // ---- apps
    readonly property real listTop: root.isSum ? 184 : (recent.visible ? 124 + 110 : (cats.visible ? 124 : 80))
    BarText {
        visible: !root.isSum && root.debounced.length === 0 && recent.visible
        x: 22; y: root.listTop - 22
        text: root.category === "all" ? "All apps" : ""
        color: BarStyle.subtext; font.pixelSize: 12
    }
    GridView {
        id: grid
        visible: root.viewMode === "grid"
        x: 10; y: root.listTop
        width: parent.width - 20; height: parent.height - y - 44
        clip: true
        cellWidth: Math.floor(width / 5); cellHeight: 112
        currentIndex: root.current
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        delegate: BarButton {
            id: tile
            required property var modelData
            required property int index
            readonly property bool isAction: modelData.action !== undefined
            readonly property bool pinned: !isAction && root.isPinned(modelData.entry)
            width: grid.cellWidth - 8; height: grid.cellHeight - 8
            radius: BarStyle.radiusLarge
            tone: "plain"
            toggled: root.current === index
            onTapped: root.launch(modelData)
            onSecondary: { if (!isAction) IrisDockOrder.togglePin(root.keyOf(modelData.entry)) }
            onHoveredChanged: if (hovered) root.current = index
            Image {
                visible: !tile.isAction
                x: Math.round((tile.width - width) / 2); y: 8
                width: 56; height: 56
                source: tile.isAction ? "" : AppSearch.getIconSource(tile.modelData.entry.icon || tile.modelData.entry.name, "application-x-executable")
                sourceSize: Qt.size(104, 104)
                smooth: true; mipmap: true; asynchronous: true
            }
            BarIcon { visible: tile.isAction; x: Math.round((tile.width - 32) / 2); y: 20; name: tile.isAction ? tile.modelData.action.icon : ""; size: 32; color: BarStyle.accent }
            BarText {
                x: 6; y: 70; width: tile.width - 12
                text: tile.isAction ? tile.modelData.action.title : (tile.modelData.entry.name ?? "")
                color: tile.ink; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            }
            BarIcon { visible: tile.pinned; x: tile.width - 22; y: 6; name: "keep"; fill: 1; size: 14; color: BarStyle.accent }
        }
    }
    ListView {
        id: list
        visible: root.viewMode === "list"
        x: 10; y: root.listTop
        width: parent.width - 20; height: parent.height - y - 44
        clip: true; spacing: 4
        currentIndex: root.current
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: BarButton {
            id: row
            required property var modelData
            required property int index
            readonly property bool isAction: modelData.action !== undefined
            readonly property bool pinned: !isAction && root.isPinned(modelData.entry)
            width: list.width; height: 56
            radius: BarStyle.radiusMedium
            tone: "plain"
            toggled: root.current === index
            onTapped: root.launch(modelData)
            onSecondary: { if (!isAction) IrisDockOrder.togglePin(root.keyOf(modelData.entry)) }
            onHoveredChanged: if (hovered) root.current = index
            Image {
                visible: !row.isAction
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                source: row.isAction ? "" : AppSearch.getIconSource(row.modelData.entry.icon || row.modelData.entry.name, "application-x-executable")
                sourceSize: Qt.size(72, 72)
                smooth: true; mipmap: true; asynchronous: true
            }
            BarIcon { visible: row.isAction; x: 18; anchors.verticalCenter: parent.verticalCenter; name: row.isAction ? row.modelData.action.icon : ""; size: 28; color: BarStyle.accent }
            BarText {
                x: 62; anchors.verticalCenter: parent.verticalCenter; width: row.width - 62 - 50
                text: row.isAction ? row.modelData.action.title : (row.modelData.entry.name ?? "")
                color: row.ink; font.pixelSize: 14; elide: Text.ElideRight
            }
            BarIcon { visible: row.pinned; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; name: "keep"; fill: 1; size: 16; color: BarStyle.accent }
        }
    }
    // the keys, quietly along the bottom
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        spacing: 18
        Repeater {
            model: [["↑↓←→", "move"], ["Enter", "open"], ["Right-click", "pin"], ["Esc", "close"]]
            delegate: Row {
                required property var modelData
                spacing: 6
                Rectangle { height: 20; width: k.width + 12; radius: 7; color: BarStyle.card
                    BarText { id: k; anchors.centerIn: parent; text: parent.parent.modelData[0]; font.pixelSize: 11; color: BarStyle.subtext } }
                BarText { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]; font.pixelSize: 11; color: BarStyle.subtext }
            }
        }
    }
    BarText {
        anchors.centerIn: parent
        visible: !root.isSum && root.items.length === 0
        text: "Nothing found"
        color: BarStyle.subtext
    }
}
