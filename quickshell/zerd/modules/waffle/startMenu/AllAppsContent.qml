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
                Text { text: "Recent"; color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.6); font.pixelSize: 12; font.weight: Font.Medium; leftPadding: 4 }
                Row {
                    spacing: 8
                    Repeater {
                        model: root.pinnedApps
                        delegate: Rectangle {
                            id: pin
                            required property var modelData
                            width: 64; height: 64; radius: 20
                            color: pinHover.hovered ? root.tileHover : root.tileIdle
                            Behavior on color { ColorAnimation { duration: 90 } }
                            scale: pinHover.hovered ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            Image {
                                anchors.centerIn: parent
                                width: 40; height: 40
                                source: AppSearch.getIconSource(pin.modelData.icon || pin.modelData.name, "application-x-executable")
                                sourceSize: Qt.size(96, 96)
                                smooth: true; mipmap: true; asynchronous: true
                            }
                            HoverHandler { id: pinHover }
                            TapHandler { onTapped: { root.launch(pin.modelData); GlobalStates.searchOpen = false } }
                        }
                    }
                }
                Text { text: "All apps"; color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.6); font.pixelSize: 12; font.weight: Font.Medium; leftPadding: 4; topPadding: 6 }
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

                delegate: WBorderlessButton {
                    id: gridItem
                    required property var modelData
                    required property int index
                    width: gridView.cellWidth - 12
                    height: gridView.cellHeight - 12
                    radius: 20
                    checked: gridView.currentIndex === index
                    colBackground: checked ? root.tileSelected : root.tileIdle
                    colBackgroundHover: checked ? root.tileSelected : root.tileHover

                    onClicked: {
                        root.launch(gridItem.modelData)
                        GlobalStates.searchOpen = false
                    }
                    onHoveredChanged: { if (hovered) gridView.currentIndex = index }

                    contentItem: ColumnLayout {
                        spacing: 6
                        Item { Layout.preferredHeight: 2 }
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 56; Layout.preferredHeight: 56
                            source: AppSearch.getIconSource(gridItem.modelData.icon || gridItem.modelData.name, "application-x-executable")
                            sourceSize: Qt.size(112, 112)
                            smooth: true; mipmap: true
                            asynchronous: true
                        }
                        WText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: gridView.cellWidth - 20
                            text: gridItem.modelData.name || ""
                            color: SMColors.fg
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }
                    }
                    WToolTip { text: gridItem.modelData.name || "" }
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

                delegate: WBorderlessButton {
                    id: listItem
                    required property var modelData
                    required property int index
                    width: listView.width
                    implicitHeight: 60
                    radius: 20
                    checked: listView.currentIndex === index
                    colBackground: checked ? root.tileSelected : root.tileIdle
                    colBackgroundHover: checked ? root.tileSelected : root.tileHover

                    onClicked: {
                        root.launch(listItem.modelData)
                        GlobalStates.searchOpen = false
                    }
                    onHoveredChanged: { if (hovered) listView.currentIndex = index }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14
                        Image {
                            Layout.alignment: Qt.AlignVCenter
                            source: AppSearch.getIconSource(listItem.modelData.icon || listItem.modelData.name, "application-x-executable")
                            sourceSize: Qt.size(88, 88)
                            width: 44; height: 44
                            smooth: true; mipmap: true
                            asynchronous: true
                        }
                        WText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: listItem.modelData.name || ""
                            color: SMColors.fg
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
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
