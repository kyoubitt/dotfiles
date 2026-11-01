import QtQuick
import QtQuick.Effects
import qs.services

// The whole app sits on the blurred cover of what is playing. The new cover fades in over the old one.
Item {
    id: root
    property string current: Playback.player?.trackArtUrl ?? ""
    property string shownA: ""
    property string shownB: ""
    property bool onA: true
    onCurrentChanged: { if (onA) shownB = current; else shownA = current; onA = !onA }
    Component.onCompleted: { shownA = current; onA = false }

    // the colour of the cover: the average of its saturated pixels, lifted so it works as a button colour
    Image { id: probe; source: root.current; sourceSize: Qt.size(24, 24); visible: false; cache: false; asynchronous: true; onStatusChanged: if (status === Image.Ready) sampler.requestPaint() }
    Canvas {
        id: sampler
        width: 24; height: 24; visible: false
        onPaint: {
            const c = getContext("2d"); c.clearRect(0, 0, 24, 24); c.drawImage(probe, 0, 0, 24, 24)
            const d = c.getImageData(0, 0, 24, 24).data
            let x = 0, y = 0, w = 0, lum = 0
            for (let i = 0; i < d.length; i += 4) {
                const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255
                lum += 0.299 * r + 0.587 * g + 0.114 * b
                const mx = Math.max(r, g, b), mn = Math.min(r, g, b), sat = mx === 0 ? 0 : (mx - mn) / mx
                const wt = sat * sat * mx
                if (wt < 0.02) continue
                let h
                if (mx === mn) h = 0
                else if (mx === r) h = ((g - b) / (mx - mn) + 6) % 6
                else if (mx === g) h = (b - r) / (mx - mn) + 2
                else h = (r - g) / (mx - mn) + 4
                x += Math.cos(h / 6 * 2 * Math.PI) * wt; y += Math.sin(h / 6 * 2 * Math.PI) * wt; w += wt
            }
            MusicStore.coverLum = lum / (d.length / 4)
            if (w < 0.6) { MusicStore.coverColor = "transparent"; return }
            const hue = ((Math.atan2(y, x) / (2 * Math.PI)) + 1) % 1
            MusicStore.coverColor = Qt.hsva(hue, 0.55, 0.92, 1)
        }
    }
    component Layer: Item {
        id: lay
        property string src: ""
        property bool on: false
        anchors.fill: parent
        opacity: on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        Image { id: img; anchors.centerIn: parent; width: parent.width * 1.4; height: width; source: lay.src; sourceSize: Qt.size(160, 160); fillMode: Image.PreserveAspectCrop; visible: false; cache: false; smooth: true }
        MultiEffect { anchors.fill: img; source: img; blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.9; brightness: 0.02; autoPaddingEnabled: false }
    }
    Layer { src: root.shownA; on: root.onA }
    Layer { src: root.shownB; on: !root.onA }
    // keeps text readable on any cover, and fades to dark at the bottom
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.3 + 0.38 * MusicStore.coverLum; Behavior on opacity { NumberAnimation { duration: 700 } } }
    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#99000000" } } }
}
