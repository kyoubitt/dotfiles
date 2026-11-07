import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
    id: root
    property bool editMode: false
    signal editToggled()

    implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)

    Rectangle {
        id: uptimeContainer
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        color: Appearance.colors.colLayer1
        radius: height / 2
        implicitWidth: uptimeRow.implicitWidth + 24
        implicitHeight: uptimeRow.implicitHeight + 8

        Row {
            id: uptimeRow
            anchors.centerIn: parent
            spacing: 8
            CustomIcon {
                id: distroIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                height: 25
                source: SystemInfo.distroIcon
                colorize: true
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Up %1").arg(DateTime.uptime)
                textFormat: Text.MarkdownText
            }
        }
    }

    ButtonGroup {
        id: systemButtonsRow
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        color: Appearance.colors.colLayer1
        padding: 4

        QuickToggleButton {
            toggled: root.editMode
            buttonIcon: "edit"
            onClicked: root.editToggled()
            StyledToolTip {
                text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
            }
        }
        QuickToggleButton {
            toggled: false
            buttonIcon: "restart_alt"
            onClicked: Quickshell.reload(true)
            StyledToolTip {
                text: Translation.tr("Reload shell")
            }
        }
        QuickToggleButton {
            toggled: false
            buttonIcon: "settings"
            onClicked: {
                BarState.closeAll()
                GlobalStates.settingsOpen = true
            }
            StyledToolTip {
                text: Translation.tr("Settings")
            }
        }
        QuickToggleButton {
            toggled: false
            buttonIcon: "power_settings_new"
            onClicked: {
                BarState.closeAll()
                GlobalStates.sessionOpen = true
            }
            StyledToolTip {
                text: Translation.tr("Session")
            }
        }
    }
}
