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
    // A sum starts with a digit, a sign, a bracket, a decimal point, a known function or "=": -5+3, (1+2)*3, .5*4, sqrt(9).
    readonly property bool isMathQuery: /^\s*[-+(.]*\s*\d/.test(root.searchText) || /^\s*[-+]?\s*\(/.test(root.searchText) || /^\s*(sqrt|sin|cos|tan|log|ln|abs|pi|e\^)/i.test(root.searchText) || root.searchText.startsWith("=")
    readonly property bool showMathResult: root.isMathQuery && LauncherSearch.mathResult !== ""

    StartMenuContext { id: context }
    // Enter in the search box opens the selected app (or copies the sum, when it is one)
    Connections {
        target: context
        function onAccepted() {
            if (root.showMathResult) mathCard.copy()
            else allApps.activateCurrent()
        }
    }

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
        radius: 28
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

            // The calculator card: what you typed, the answer big, and one click to copy it.
            Rectangle {
                id: mathCard
                visible: root.showMathResult
                Layout.fillWidth: true
                implicitHeight: 92
                radius: 22
                antialiasing: true
                color: ColorUtils.mix(SMColors.accent, SMColors.bg, 0.16)
                property bool copied: false
                // the answer with a real minus sign, so it pastes into anything
                readonly property string plain: String(LauncherSearch.mathResult).replace(/\u2212/g, "-")
                function copy(): void {
                    Quickshell.clipboardText = mathCard.plain
                    mathCard.copied = true
                    copyReset.restart()
                    closeAfter.restart()
                }
                Timer { id: copyReset; interval: 1200; onTriggered: mathCard.copied = false }
                Timer { id: closeAfter; interval: 420; onTriggered: GlobalStates.searchOpen = false }
                opacity: visible ? 1 : 0
                scale: visible ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 16; anchors.topMargin: 12; anchors.bottomMargin: 12
                    spacing: 2
                    WText {
                        Layout.fillWidth: true
                        text: root.searchText.replace(/^=/, "").trim()
                        font.pixelSize: 13
                        font.family: "monospace"
                        color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.55)
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        WText {
                            id: answer
                            Layout.fillWidth: true
                            text: "= " + mathCard.plain
                            font.pixelSize: 30
                            font.weight: Font.Bold
                            color: SMColors.accent
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: copyRow.implicitWidth + 24; implicitHeight: 34; radius: 17
                            color: mathCard.copied ? SMColors.accent : (copyHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09))
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                id: copyRow; anchors.centerIn: parent; spacing: 6
                                Text { text: mathCard.copied ? "check" : "content_copy"; font.family: "Material Symbols Rounded"; font.pixelSize: 16; color: mathCard.copied ? SMColors.bg : SMColors.fg }
                                WText { text: mathCard.copied ? Translation.tr("Copied") : Translation.tr("Copy"); font.pixelSize: 13; color: mathCard.copied ? SMColors.bg : SMColors.fg }
                            }
                            HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mathCard.copy() }
            }

            Item {
                visible: !root.showMathResult
                implicitHeight: 520
                implicitWidth: 632
                Layout.fillWidth: true
                clip: true

                AllAppsContent {
                    id: allApps
                    anchors.fill: parent
                    filterText: root.searchText
                    viewMode: root.appViewMode
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
}
