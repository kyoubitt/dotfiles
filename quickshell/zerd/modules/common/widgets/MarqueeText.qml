import QtQuick
import QtQuick.Layouts

Item {
    id: marquee

    property alias text: label1.text
    property alias font: label1.font
    property alias color: label1.color
    readonly property real gapWidth: 24

    Layout.alignment: Qt.AlignVCenter
    implicitHeight: label1.implicitHeight
    clip: true

    readonly property bool needsScroll: label1.implicitWidth > marquee.width
    readonly property real unitWidth: label1.implicitWidth + marquee.gapWidth

    // Distance scrolled so far, always in [0, unitWidth]. Kept separate from
    // scrollRow.x itself so x can stay a plain live binding - animating x
    // directly meant every loop broke the binding and left a stale offset
    // behind whenever needsScroll flipped mid-scroll, which is what made
    // short (non-scrolling) titles sometimes render fully offscreen.
    property real _scrollOffset: 0
    onTextChanged: _scrollOffset = 0
    onNeedsScrollChanged: _scrollOffset = 0

    Row {
        id: scrollRow
        height: parent.height
        // Sits at 0 whenever the text fits - only offset while actually scrolling.
        x: marquee.needsScroll ? -marquee._scrollOffset : 0

        Text {
            id: label1
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
        }
        Item {
            width: marquee.gapWidth
            height: 1
            visible: marquee.needsScroll
        }
        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            visible: marquee.needsScroll
            text: label1.text
            font: label1.font
            color: label1.color
            renderType: Text.NativeRendering
        }
    }

    SequentialAnimation {
        running: marquee.needsScroll
        loops: Animation.Infinite

        PauseAnimation { duration: 1000 }
        NumberAnimation {
            target: marquee
            property: "_scrollOffset"
            from: 0
            to: marquee.unitWidth
            duration: Math.max(1500, marquee.unitWidth * 17)
            easing.type: Easing.Linear
        }
        // Content at offset=unitWidth (start of duplicate copy) is visually
        // identical to offset=0 (start of the original), so looping back to
        // "from" here is an invisible snap.
        PauseAnimation { duration: 600 }
    }
}
