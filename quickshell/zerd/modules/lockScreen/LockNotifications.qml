import QtQuick
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu

// Notifications grouped by app: icon, app name, latest summary, count.
// A header shows the total with a "clear all" button; hovering a card swaps
// its count for an x that dismisses that app's notifications. Scrolls with
// the mouse wheel. Message bodies are never drawn; a lock screen is visible
// to anyone passing. Hidden entirely when `lock.showNotifications` is off.
Item {
    id: root

    readonly property int headerHeight: 28
    readonly property int headerGap: 10
    readonly property int cardHeight: 48
    readonly property int cardSpacing: 8
    readonly property int maxVisible: 3

    readonly property var groups: {
        const byApp = {}
        for (const n of Notifications.list) {
            if (!n.appName) continue
            const g = byApp[n.appName]
            if (!g) byApp[n.appName] = { app: n.appName, icon: n.appIcon, summary: n.summary, time: n.time, count: 1, ids: [n.notificationId] }
            else {
                g.count += 1
                g.ids.push(n.notificationId)
                if (n.time > g.time) { g.time = n.time; g.summary = n.summary; g.icon = n.appIcon }
            }
        }
        return Object.values(byApp).sort((a, b) => b.time - a.time)
    }
    readonly property int total: groups.reduce((sum, g) => sum + g.count, 0)

    visible: (Config.options?.lock?.showNotifications ?? true) && groups.length > 0
    implicitWidth: 380
    implicitHeight: headerHeight + headerGap
        + Math.min(column.implicitHeight, maxVisible * cardHeight + (maxVisible - 1) * cardSpacing)

    // ---------------- header ----------------
    LockText {
        x: 6
        y: 0
        height: root.headerHeight
        verticalAlignment: Text.AlignVCenter
        text: `notifications · ${root.total}`
        opacity: 0.7
        font.pixelSize: 13
        font.weight: Font.Medium
        font.letterSpacing: 0.3
    }

    Rectangle {
        id: clearBtn
        anchors.right: parent.right
        y: 0
        width: clearRow.implicitWidth + 24
        height: root.headerHeight
        radius: height / 2
        antialiasing: true
        color: clearMouse.containsMouse ? ColorUtils.applyAlpha(SMColors.fg, 0.16) : ColorUtils.applyAlpha("#000000", 0.3)
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, clearMouse.containsMouse ? 0.5 : 0.28)
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Row {
            id: clearRow
            anchors.centerIn: parent
            spacing: 6
            LockIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "done_all"
                iconSize: 16
            }
            LockText {
                anchors.verticalCenter: parent.verticalCenter
                text: "clear all"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifications.discardAllNotifications()
        }
    }

    // ---------------- list ----------------
    Flickable {
        id: flick
        x: 0
        y: root.headerHeight + root.headerGap
        width: root.width
        height: root.height - y
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        // Soft fade where more cards are hidden above/below. Only rasterised
        // into a layer when the list actually scrolls, so a short list keeps
        // fully crisp text.
        layer.enabled: contentHeight > height + 1
        layer.effect: GE.OpacityMask {
            maskSource: fadeMask
        }

        Column {
            id: column
            width: flick.width
            spacing: root.cardSpacing

            Repeater {
                model: root.groups

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property string iconSource: AppSearch.getIconSource(modelData.app, "")

                    width: column.width
                    height: root.cardHeight
                    radius: height / 2
                    antialiasing: true
                    color: ColorUtils.applyAlpha("#000000", 0.4)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(SMColors.fg, cardHover.hovered ? 0.4 : 0.25)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: cardHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: width / 2
                            antialiasing: true
                            color: ColorUtils.applyAlpha(SMColors.accent, 0.18)

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                sourceSize: Qt.size(24, 24)
                                mipmap: true
                                smooth: true
                                source: card.iconSource
                                visible: status === Image.Ready
                            }
                            LockText {
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                text: card.modelData.app[0].toUpperCase()
                                color: SMColors.accent
                                font.pixelSize: 15
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            LockText {
                                Layout.fillWidth: true
                                text: card.modelData.app
                                elide: Text.ElideRight
                                opacity: 0.65
                                font.pixelSize: 12
                            }
                            LockText {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                elide: Text.ElideRight
                                font.pixelSize: 13
                            }
                        }

                        // Count, swapped for a dismiss button while hovered.
                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            LockText {
                                anchors.centerIn: parent
                                visible: card.modelData.count > 1 && !cardHover.hovered
                                text: card.modelData.count
                                color: SMColors.accent
                                font.pixelSize: 13
                                font.bold: true
                            }
                            LockIcon {
                                anchors.centerIn: parent
                                visible: cardHover.hovered
                                text: "close"
                                iconSize: 18
                                opacity: dismissMouse.containsMouse ? 1 : 0.65
                            }
                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                enabled: cardHover.hovered
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    for (const id of card.modelData.ids.slice())
                                        Notifications.discardNotification(id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Mask for the fade: opaque in the middle, transparent at an edge only
    // when there is more content in that direction.
    Item {
        id: fadeMask
        x: flick.x
        y: flick.y
        width: flick.width
        height: flick.height
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: flick.atYBeginning ? "#ffffff" : "#00ffffff" }
                GradientStop { position: 0.18; color: "#ffffffff" }
                GradientStop { position: 0.82; color: "#ffffffff" }
                GradientStop { position: 1.0; color: flick.atYEnd ? "#ffffff" : "#00ffffff" }
            }
        }
    }

    // Thin scroll indicator, shown only while scrolling.
    Rectangle {
        x: parent.width + 8
        y: flick.y + flick.visibleArea.yPosition * flick.height
        width: 3
        height: Math.max(16, flick.visibleArea.heightRatio * flick.height)
        radius: 2
        color: SMColors.fg
        opacity: flick.moving && flick.visibleArea.heightRatio < 1 ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
}
