pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu
import qs.modules.iris.dock
import qs.modules.bars

WPanelPageColumn {
    id: root

    property string filterText: ""
    property string viewMode: "grid" // "grid" or "list"
    // Material-style tonal surfaces and state layers over the wallust colours.
    readonly property color tileIdle: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.07)
    readonly property color tileHover: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.15)
    readonly property color tileSelected: ColorUtils.mix(SMColors.accent, SMColors.bg, 0.26)

    // The apps launched most recently (not pinned: nothing is pinned any more), kept in the config.
    readonly property var recentIds: Config.options?.iris?.launcher?.recent ?? []
    readonly property var pinnedApps: {
        const all = DesktopEntries.applications.values
        const out = []
        for (const id of root.recentIds) {
            const e = all.find(a => String(a.id) === String(id))
            if (e && !e.noDisplay && !out.includes(e)) out.push(e)
        }
        return out.slice(0, 6)
    }
    // Starts an app. Orbit is part of this shell, so it is opened directly instead of by running a command.
    function launch(entry): void {
        const id = String(entry?.id ?? "").toLowerCase()
        console.log("[launch] id=" + id)
        // the launch comes first; remembering it as "recent" is a nicety that must never get in the way
        if (id === "orbit" || id === "orbit.desktop") GlobalStates.musicRequest++
        else entry.execute()
        try { root.noteLaunch(entry) } catch (e) { console.log("[launch] recent failed: " + e) }
    }
    function noteLaunch(entry): void {
        const id = String(entry?.id ?? "")
        if (id.length === 0) return
        const next = [id].concat(root.recentIds.filter(x => String(x) !== id)).slice(0, 6)
        Config.setNestedValue("iris.launcher.recent", next)
    }

    // Debounced so the grid doesn't re-layout every delegate on every keystroke -
    // that full rebuild per character was the source of the janky/laggy typing feel.
    property string debouncedFilterText: filterText
    Timer {
        id: filterDebounce
        interval: 80
        onTriggered: root.debouncedFilterText = root.filterText
    }
    onFilterTextChanged: filterDebounce.restart()

    // Quickshell's own panels aren't real .desktop entries, so DesktopEntries
    // never sees them - without these they're simply unfindable from here no
    // matter what triggers elsewhere (dock icons, keybinds) point at them.
    readonly property var shellActions: [
    ]

    readonly property var filteredApps: {
        const filter = root.debouncedFilterText.toLowerCase().trim()
        // With nothing typed, the list leaves out the tools nobody opens (Settings > Launcher edits the list);
        // typing a name still finds them.
        const hide = (Config.options?.iris?.launcher?.hidden ?? []).map(h => String(h).toLowerCase())
        const apps = DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (filter.length === 0
                ? !hide.some(h => (e.name || "").toLowerCase().includes(h) || String(e.id || "").toLowerCase().includes(h))
                : (e.name || "").toLowerCase().includes(filter)))
        const actions = root.shellActions
            .filter(e => filter.length === 0 || e.name.toLowerCase().includes(filter))
        return [...actions, ...apps].sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    }

    function navigateUp() {
        if (root.viewMode === "grid") {
            if (gridView.currentIndex >= gridView.columns) gridView.currentIndex -= gridView.columns
        } else if (listView.currentIndex > 0) listView.currentIndex--
    }

    function navigateDown() {
        if (root.viewMode === "grid") {
            if (gridView.currentIndex + gridView.columns < gridView.count) gridView.currentIndex += gridView.columns
        } else if (listView.currentIndex < listView.count - 1) listView.currentIndex++
    }

    function activateCurrent() {
        const item = root.viewMode === "grid" ? gridView.currentItem : listView.currentItem
        if (item?.modelData) { root.launch(item.modelData); GlobalStates.searchOpen = false }
    }

    BodyRectangle {
        Layout.fillWidth: true
        implicitHeight: 632
        implicitWidth: 632
        color: SMColors.bg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Recent: the last apps you opened
            Column {
                Layout.fillWidth: true
                visible: root.filterText.length === 0 && root.pinnedApps.length > 0
                spacing: 6
                BarText { text: "Recent"; color: BarStyle.subtext; font.pixelSize: 12; leftPadding: 6 }
                Row {
                    spacing: 8
                    Repeater {
                        model: root.pinnedApps
                        delegate: BarButton {
                            id: pin
                            required property var modelData
                            width: 64; height: 64
                            radius: BarStyle.radiusLarge
                            onTapped: { root.launch(pin.modelData); GlobalStates.searchOpen = false }
                            Image {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                source: AppSearch.getIconSource(pin.modelData.icon || pin.modelData.name, "application-x-executable")
                                sourceSize: Qt.size(96, 96)
                                smooth: true; mipmap: true; asynchronous: true
                            }
                        }
                    }
                }
                Text { text: "All apps"; color: BarStyle.subtext; font.pixelSize: 12; leftPadding: 6; topPadding: 6 }
            }

            GridView {
                id: gridView
                visible: root.viewMode === "grid"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                // Five columns that fill the row exactly, so the left and right gaps match.
                cellWidth: Math.floor(gridView.width / 5)
                cellHeight: 120
                currentIndex: 0
                highlightMoveDuration: 100
                cacheBuffer: 400
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; implicitWidth: 6 }

                model: root.filteredApps

                delegate: BarButton {
                    id: gridItem
                    required property var modelData
                    required property int index
                    width: gridView.cellWidth - 12
                    height: gridView.cellHeight - 12
                    radius: BarStyle.radiusLarge
                    toggled: gridView.currentIndex === index
                    onTapped: {
                        root.launch(gridItem.modelData)
                        GlobalStates.searchOpen = false
                    }
                    onHoveredChanged: { if (hovered) gridView.currentIndex = index }

                    Image {
                        x: Math.round((gridItem.width - width) / 2)
                        y: 12
                        width: 56; height: 56
                        source: AppSearch.getIconSource(gridItem.modelData.icon || gridItem.modelData.name, "application-x-executable")
                        sourceSize: Qt.size(112, 112)
                        smooth: true; mipmap: true
                        asynchronous: true
                    }
                    BarText {
                        x: 8
                        y: 76
                        width: gridItem.width - 16
                        text: gridItem.modelData.name || ""
                        color: gridItem.ink
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: gridView.count === 0
                    text: Translation.tr("No apps found")
                    color: Looks.colors.fg1
                }
            }

            ListView {
                id: listView
                visible: root.viewMode === "list"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                currentIndex: 0
                highlightMoveDuration: 100

                model: root.filteredApps

                delegate: BarButton {
                    id: listItem
                    required property var modelData
                    required property int index
                    width: listView.width
                    height: 60
                    radius: BarStyle.radiusMedium
                    toggled: listView.currentIndex === index
                    onTapped: {
                        root.launch(listItem.modelData)
                        GlobalStates.searchOpen = false
                    }
                    onHoveredChanged: { if (hovered) listView.currentIndex = index }

                    Image {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        source: AppSearch.getIconSource(listItem.modelData.icon || listItem.modelData.name, "application-x-executable")
                        sourceSize: Qt.size(88, 88)
                        width: 44; height: 44
                        smooth: true; mipmap: true
                        asynchronous: true
                    }
                    BarText {
                        x: 72
                        anchors.verticalCenter: parent.verticalCenter
                        width: listItem.width - 72 - 16
                        text: listItem.modelData.name || ""
                        color: listItem.ink
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: Translation.tr("No apps found")
                    color: Looks.colors.fg1
                }
            }
        }
    }
}
