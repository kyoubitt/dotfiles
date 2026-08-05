import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// Single grid cell: a wallpaper thumbnail or a folder to browse into.
MouseArea {
    id: root
    required property var fileModelData
    property bool useThumbnail: !fileModelData.fileIsDir
    property bool isCurrent: false

    signal activated()

    hoverEnabled: true
    onClicked: root.activated()

    scale: pressed ? 0.95 : 1.0
    Behavior on scale {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        // Selection/hover ring drawn as a border overlay
        border.width: root.isCurrent ? 2 : (root.containsMouse ? 1 : 0)
        border.color: root.isCurrent
            ? Appearance.colors.colPrimary
            : Appearance.colors.colOutlineVariant

        Behavior on border.width {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        // Thumbnail fills the whole card (no inner margin)
        Loader {
            id: thumbnailLoader
            anchors.fill: parent
            active: root.useThumbnail

            sourceComponent: ThumbnailImage {
                id: thumbnailImage
                generateThumbnail: false
                thumbnailSizeName: "xx-large"
                sourcePath: fileModelData.filePath

                cache: true
                fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                clip: true
                sourceSize.width: thumbnailLoader.width
                sourceSize.height: thumbnailLoader.height

                Connections {
                    target: Wallpapers
                    function onThumbnailGenerated(directory) {
                        if (thumbnailImage.status !== Image.Error) return
                        if (FileUtils.parentDirectory(thumbnailImage.sourcePath) !== directory) return
                        thumbnailImage.source = ""
                        thumbnailImage.source = thumbnailImage.thumbnailPath
                    }
                    function onThumbnailGeneratedFile(filePath) {
                        if (thumbnailImage.status !== Image.Error) return
                        if (Qt.resolvedUrl(thumbnailImage.sourcePath) !== Qt.resolvedUrl(filePath)) return
                        thumbnailImage.source = ""
                        thumbnailImage.source = thumbnailImage.thumbnailPath
                    }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: thumbnailLoader.width
                        height: thumbnailLoader.height
                        radius: Appearance.rounding.normal
                    }
                }
            }
        }

        // Folder icon (no thumbnail)
        Loader {
            anchors.fill: parent
            active: !root.useThumbnail
            sourceComponent: DirectoryIcon {
                fileModelData: root.fileModelData
            }
        }

        // Hover/current name overlay — gradient scrim at the bottom of image tiles
        Rectangle {
            id: nameScrim
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: nameLabel.implicitHeight + 16
            radius: Appearance.rounding.normal
            // Only round the bottom corners by overlapping with a non-rounded rect above
            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.radius
                color: parent.color
                opacity: parent.opacity
            }

            visible: root.useThumbnail && (root.containsMouse || root.isCurrent)
            opacity: root.containsMouse || root.isCurrent ? 1.0 : 0.0
            color: "transparent"

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
            }

            // Dark gradient so text is always readable
            LinearGradient {
                anchors.fill: parent
                start: Qt.point(0, 0)
                end: Qt.point(0, parent.height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#cc000000" }
                }
            }

            StyledText {
                id: nameLabel
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: 8
                }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: "#ffffff"
                text: fileModelData.fileName
            }
        }

        // Folder name label (always visible for dirs)
        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 6
            }
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            text: fileModelData.fileName
            visible: !root.useThumbnail
        }
    }
}
