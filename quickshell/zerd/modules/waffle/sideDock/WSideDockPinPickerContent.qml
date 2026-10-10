pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.startMenu

// A small, dock-native "manage pinned apps" list - not a second Start
// Menu. Doubles as the pin AND unpin UI: every installed app shows here
// with a live toggle, whether or not it's currently running, so pinning an
// app that isn't open (the one thing the dock's own hover-badge can't do)
// and unpinning one both happen from this single searchable list.
Item {
    id: root

    signal closed()
    function close() { closeAnim.start() }

    implicitWidth: 300
    implicitHeight: 420

    focus: true
    Keys.onEscapePressed: root.close()

    opacity: 0
    scale: 0.94
    transformOrigin: Item.Center
    Component.onCompleted: {
        openAnim.start()
        searchInput.forceActiveFocus()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "scale"; to: 0.94; duration: 120; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.closed() }
    }

    property string filterText: ""
    // Same debounce idiom as AllAppsContent - avoids re-laying-out the
    // whole list on every keystroke.
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

    Rectangle {
        anchors.fill: parent
        radius: 16
        antialiasing: true
        color: SMColors.bg
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.18)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    id: searchCard
                    Layout.fillWidth: true
                    implicitHeight: searchRow.implicitHeight + 16
                    radius: 12
                    antialiasing: true
                    color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.12)
                    border.width: 1
                    border.color: searchInput.activeFocus ? SMColors.fg : ColorUtils.mix(SMColors.fg, SMColors.bg, 0.25)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: searchRow
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: "search"
                            iconSize: 16
                            color: SMColors.fg
                        }

                        WTextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: SMColors.fg
                            font.pixelSize: 14
                            onTextChanged: root.filterText = searchInput.text

                            WText {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                color: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.6)
                                text: Translation.tr("Search apps to pin")
                                visible: searchInput.text.length === 0
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                // Explicit close button - click-outside and Escape both
                // still work, but neither is an obvious affordance on
                // first glance.
                Rectangle {
                    id: closeBtn
                    Layout.preferredWidth: searchCard.implicitHeight
                    Layout.preferredHeight: searchCard.implicitHeight
                    radius: width / 2
                    antialiasing: true
                    color: closeMouse.containsMouse ? ColorUtils.mix(SMColors.fg, SMColors.bg, 0.2) : ColorUtils.mix(SMColors.fg, SMColors.bg, 0.12)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: SMColors.fg
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.filteredApps

                delegate: Item {
                    id: rowBtn
                    required property var modelData
                    width: listView.width
                    implicitHeight: 44

                    readonly property bool pinned: DockPins.isAppPinned(rowBtn.modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        antialiasing: true
                        color: rowHover.hovered ? ColorUtils.mix(SMColors.fg, SMColors.bg, 0.14) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    HoverHandler { id: rowHover }

                    // Click the row itself to launch - this list reads as
                    // an app launcher (search bar, icon, name, same as
                    // AllAppsContent) and did nothing at all when clicked
                    // outside the small pin badge, which just looked
                    // broken. The dedicated pin button sits on top of this
                    // (declared after, so it gets the click first) and
                    // still only pins/unpins - launching stays exclusive to
                    // the rest of the row, so there's no more risk of a
                    // stray click silently unpinning something than before.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rowBtn.modelData.execute()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Image {
                            Layout.alignment: Qt.AlignVCenter
                            source: AppSearch.getIconSource(rowBtn.modelData.icon || rowBtn.modelData.name, "application-x-executable")
                            sourceSize: Qt.size(28, 28)
                            width: 28
                            height: 28
                            asynchronous: true
                        }
                        WText {
                            Layout.fillWidth: true
                            text: rowBtn.modelData.name || ""
                            color: SMColors.fg
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        // The one actual pin/unpin control - push_pin to
                        // add, an explicit x to remove, matching the same
                        // glyph pair used everywhere else in the dock
                        // (the icon's own hover badge, the context menu).
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            antialiasing: true
                            color: pinMouse.containsMouse
                                ? ColorUtils.applyAlpha(SMColors.fg, 0.18)
                                : ColorUtils.applyAlpha(SMColors.fg, 0.08)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: rowBtn.pinned ? "close" : "push_pin"
                                iconSize: 14
                                color: rowBtn.pinned ? SMColors.accent : ColorUtils.applyAlpha(SMColors.fg, 0.7)
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: pinMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DockPins.toggleAppPin(rowBtn.modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    text: Translation.tr("No apps found")
                    color: ColorUtils.applyAlpha(SMColors.fg, 0.6)
                    font.pixelSize: 13
                }
            }
        }
    }
}
