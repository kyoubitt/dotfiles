import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true
    settingsPageIndex: 11
    settingsPageName: Translation.tr("About")

    SettingsCardSection {
        expanded: true
        icon: "computer"
        title: Translation.tr("System")

        SettingsGroup {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                Item {
                    width: 64
                    height: 64

                    Image {
                        id: distroIconImage
                        anchors.fill: parent
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: Quickshell.shellPath(`assets/icons/${SystemInfo.distroIcon}.svg`)
                        fillMode: Image.PreserveAspectFit
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: distroIconImage
                        source: distroIconImage
                        colorization: 1.0
                        colorizationColor: Appearance.m3colors.m3primary
                        visible: distroIconImage.status === Image.Ready
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: distroIconImage.status !== Image.Ready
                        text: "computer"
                        iconSize: 64
                        color: Appearance.m3colors.m3primary
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    StyledText {
                        text: SystemInfo.distroName || "Linux"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }
                    StyledText {
                        visible: SystemInfo.homeUrl && SystemInfo.homeUrl.length > 0
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        text: SystemInfo.homeUrl ? `[${SystemInfo.homeUrl}](${SystemInfo.homeUrl})` : ""
                        textFormat: Text.MarkdownText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                        PointingHandLinkHover {}
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 5

                RippleButtonWithIcon {
                    visible: SystemInfo.documentationUrl && SystemInfo.documentationUrl.length > 0
                    materialIcon: "auto_stories"
                    mainText: Translation.tr("Documentation")
                    onClicked: Qt.openUrlExternally(SystemInfo.documentationUrl)
                }
                RippleButtonWithIcon {
                    visible: SystemInfo.supportUrl && SystemInfo.supportUrl.length > 0
                    materialIcon: "support"
                    mainText: Translation.tr("Help & Support")
                    onClicked: Qt.openUrlExternally(SystemInfo.supportUrl)
                }
                RippleButtonWithIcon {
                    visible: SystemInfo.bugReportUrl && SystemInfo.bugReportUrl.length > 0
                    materialIcon: "bug_report"
                    mainText: Translation.tr("Report a Bug")
                    onClicked: Qt.openUrlExternally(SystemInfo.bugReportUrl)
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "favorite"
        title: Translation.tr("Based on")

        SettingsGroup {
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                Layout.topMargin: 10
                Layout.bottomMargin: 10

                Item {
                    width: 64
                    height: 64

                    Image {
                        id: shellIcon
                        anchors.fill: parent
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: Quickshell.shellPath("assets/icons/zerda-shell.svg")
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: shellIcon.status !== Image.Ready
                        text: "favorite"
                        iconSize: 64
                        color: Appearance.m3colors.m3primary
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    StyledText {
                        text: "zerda-shell"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("zerda's personal desktop shell for Niri.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }
}
