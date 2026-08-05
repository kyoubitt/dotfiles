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

WPanelPageColumn {
    id: root

    property string filterText: ""
    property string viewMode: "grid" // "grid" or "list"
    readonly property color tileIdle: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.12)
    readonly property color tileHover: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.20)

    // Debounced so the grid doesn't re-layout every delegate on every keystroke -
    // that full rebuild per character was the source of the janky/laggy typing feel.
    property string debouncedFilterText: filterText
    Timer {
        id: filterDebounce
        interval: 80
        onTriggered: root.debouncedFilterText = root.filterText
    }
    onFilterTextChanged: filterDebounce.restart()

    readonly property var filteredApps: {
        const filter = root.debouncedFilterText.toLowerCase().trim()
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (filter.length === 0 || (e.name || "").toLowerCase().includes(filter)))
            .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
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
        if (item) item.clicked()
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

            GridView {
                id: gridView
                visible: root.viewMode === "grid"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 120
                cellHeight: 120
                currentIndex: 0
                highlightMoveDuration: 100
                cacheBuffer: 400

                model: root.filteredApps

                delegate: WBorderlessButton {
                    id: gridItem
                    required property var modelData
                    required property int index
                    width: gridView.cellWidth - 12
                    height: gridView.cellHeight - 12
                    radius: 15
                    checked: gridView.currentIndex === index
                    colBackground: root.tileIdle
                    colBackgroundHover: root.tileHover

                    onClicked: {
                        gridItem.modelData.execute()
                        GlobalStates.searchOpen = false
                    }
                    onHoveredChanged: { if (hovered) gridView.currentIndex = index }

                    contentItem: ColumnLayout {
                        spacing: 6
                        Item { Layout.preferredHeight: 2 }
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: AppSearch.getIconSource(gridItem.modelData.icon || gridItem.modelData.name, "application-x-executable")
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                        }
                        WText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: gridView.cellWidth - 20
                            text: gridItem.modelData.name || ""
                            color: SMColors.fg
                            font.pixelSize: 14
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
                    radius: 12
                    checked: listView.currentIndex === index
                    colBackground: root.tileIdle
                    colBackgroundHover: root.tileHover

                    onClicked: {
                        listItem.modelData.execute()
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
                            sourceSize: Qt.size(44, 44)
                            width: 44; height: 44
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
