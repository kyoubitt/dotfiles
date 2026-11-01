import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

// Now playing: cover, title over artist, transport controls.
Rectangle {
    id: root

    implicitWidth: 380
    implicitHeight: 72
    radius: height / 2
    color: ColorUtils.applyAlpha("#000000", 0.45)
    border.width: 1
    border.color: ColorUtils.applyAlpha(SMColors.fg, 0.25)

    readonly property string artUrl: NowPlaying.activeTrack?.artUrl ?? ""

    component Transport: Item {
        id: tr
        property string icon: ""
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        LockIcon {
            anchors.centerIn: parent
            text: tr.icon
            fill: 1
            iconSize: 22
            color: SMColors.fg
            opacity: trMouse.containsMouse ? 1 : 0.75
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: trMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tr.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 16
        spacing: 12

        // Cover art, circle-cropped to match the card; note icon if there is none.
        Item {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ColorUtils.applyAlpha(SMColors.accent, 0.18)
                LockIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    fill: 1
                    iconSize: 22
                    color: SMColors.accent
                }
            }
            Image {
                id: cover
                anchors.fill: parent
                visible: false
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(52, 52)
                mipmap: true
                smooth: true
                antialiasing: true
                source: root.artUrl
            }
            Item {
                id: coverMask
                anchors.fill: cover
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
            }
            MultiEffect {
                anchors.fill: cover
                source: cover
                maskEnabled: true
                maskSource: coverMask
                visible: cover.status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            LockText {
                Layout.fillWidth: true
                text: NowPlaying.activeTrack?.title ?? ""
                elide: Text.ElideRight
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            LockText {
                Layout.fillWidth: true
                text: NowPlaying.activeTrack?.artist ?? ""
                elide: Text.ElideRight
                opacity: 0.65
                font.pixelSize: 13
            }
        }

        Transport { icon: "skip_previous"; onClicked: NowPlaying.previous() }
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: width / 2
            color: SMColors.accent
            LockIcon {
                anchors.centerIn: parent
                text: NowPlaying.isPlaying ? "pause" : "play_arrow"
                fill: 1
                iconSize: 22
                color: SMColors.bg
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: NowPlaying.togglePlaying()
            }
        }
        Transport { icon: "skip_next"; onClicked: NowPlaying.next() }
    }
}
