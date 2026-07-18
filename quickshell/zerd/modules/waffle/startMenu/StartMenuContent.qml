pragma ComponentBehavior: Bound
import Qt.labs.synchronizer
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

WBarAttachedPanelContent {
    id: root

    property bool searching: false
    property string searchText: LauncherSearch.query
    property bool showAllApps: false
    property string appViewMode: "grid"
    readonly property color tileIdle: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.12)
    readonly property color tileHover: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.20)
    readonly property bool isMathQuery: /^\d/.test(root.searchText) || root.searchText.startsWith("=")
    readonly property bool showMathResult: root.isMathQuery && LauncherSearch.mathResult !== ""

    StartMenuContext { id: context }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) return;

        if (event.key === Qt.Key_Backspace) {
            searchBar.forceFocus();
            const text = searchBar.text;
            const pos = searchBar.searchInput?.cursorPosition ?? text.length;
            if (pos > 0) {
                if (event.modifiers & Qt.ControlModifier) {
                    const left = text.slice(0, pos);
                    const match = left.match(/(\s*\S+)\s*$/);
                    const deleteLen = match ? match[0].length : 1;
                    searchBar.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                } else {
                    searchBar.text = text.slice(0, pos - 1) + text.slice(pos);
                }
            }
            event.accepted = true;
            return;
        }

        if (event.text && event.text.length === 1 && 
            event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && 
            event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
            if (!searchBar.searchInput?.activeFocus) {
                searchBar.forceFocus();
                searchBar.text += event.text;
                event.accepted = true;
                context.setCurrentIndex(0);
            }
        }

        if (event.key === Qt.Key_Down) {
            const maxIndex = Math.max(0, LauncherSearch.results.length - 1);
            context.setCurrentIndex(Math.min(context.currentIndex + 1, maxIndex));
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            context.setCurrentIndex(Math.max(context.currentIndex - 1, 0));
            event.accepted = true;
        }
    }

    contentItem: WPane {
        color: SMColors.bg
        contentItem: WPanelPageColumn {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SearchBar {
                    id: searchBar
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalPadding: 12
                    Synchronizer on searching { property alias target: root.searching }
                    focus: true
                    text: root.searchText
                    onTextChanged: LauncherSearch.query = text
                    onAccepted: context.accepted()
                }

                Rectangle {
                    id: viewToggle
                    implicitWidth: row.implicitWidth + 16
                    implicitHeight: row.implicitHeight + 16
                    radius: 24
                    antialiasing: true
                    color: root.tileIdle

                    RowLayout {
                        id: row
                        anchors.centerIn: parent
                        spacing: 4

                        WBorderlessButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 12
                            checked: root.appViewMode === "grid"
                            colBackground: checked ? SMColors.accent : "transparent"
                            colBackgroundHover: checked ? ColorUtils.lighten(SMColors.accent, 0.1) : root.tileHover
                            onClicked: root.appViewMode = "grid"
                            contentItem: Text {
                                anchors.centerIn: parent
                                text: "grid_view"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: root.appViewMode === "grid" ? SMColors.bg : SMColors.fg
                            }
                        }

                        WBorderlessButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 12
                            checked: root.appViewMode === "list"
                            colBackground: checked ? SMColors.accent : "transparent"
                            colBackgroundHover: checked ? ColorUtils.lighten(SMColors.accent, 0.1) : root.tileHover
                            onClicked: root.appViewMode = "list"
                            contentItem: Text {
                                anchors.centerIn: parent
                                text: "list"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 18
                                color: root.appViewMode === "list" ? SMColors.bg : SMColors.fg
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.showMathResult
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 15
                antialiasing: true
                color: root.tileIdle

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: "calculate"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: SMColors.accent
                    }
                    WText {
                        Layout.fillWidth: true
                        text: LauncherSearch.mathResult
                        font.pixelSize: 20
                        color: SMColors.fg
                        elide: Text.ElideRight
                    }
                    WText {
                        text: Translation.tr("Click to copy")
                        font.pixelSize: 12
                        color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.5)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.clipboardText = LauncherSearch.mathResult
                        GlobalStates.searchOpen = false
                    }
                }
            }

            Item {
                visible: !root.showMathResult
                implicitHeight: 520
                implicitWidth: 632
                Layout.fillWidth: true
                clip: true

                AllAppsContent {
                    anchors.fill: parent
                    filterText: root.searchText
                    viewMode: root.appViewMode
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
