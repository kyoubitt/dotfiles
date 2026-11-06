import QtQuick

// The press-and-hold behind one power capsule, with no drawing of its own.
//   level  0..1  how full the capsule is: 0 idle, 0.5 while the pointer rests on it, 1 when it fires
//   holding      the button (or a key) is down right now; it fills for as long as this stays true
// It is a small per-frame integrator rather than a chain of start/stop animations, so a hold can never be restarted or lost:
// while `holding` the level climbs at a fixed rate, otherwise it settles on the resting level (0.5 hovered, 0 away).
// A tap (let go early) does not fire anything; it only emits tapped() so the view can say "hold".
Item {
    id: root
    property real weight: 1                           // heavier actions take longer to confirm
    property bool selected: false                     // chosen with the keyboard
    property bool keyHeld: false                      // a key is down
    property real fillSeconds: 0.55 + 0.5 * weight    // seconds to go from half to full

    readonly property bool hovered: ma.containsMouse
    readonly property bool holding: ma.pressed || keyHeld
    readonly property bool resting: hovered || selected
    readonly property real goal: holding ? 1 : (resting ? 0.5 : 0)
    property real level: 0
    property bool fired: false
    property real heldFor: 0                          // seconds of the current press

    signal activated()
    signal tapped()

    function reset(): void { fired = false; level = 0; heldFor = 0 }
    function keyDown(): void { keyHeld = true }
    function keyUp(): void { keyHeld = false }

    onHoldingChanged: {
        if (holding) heldFor = 0
        else if (!fired && heldFor > 0 && heldFor < 0.3) tapped()
    }

    function step(dt: real): void {
        dt = Math.min(dt, 0.05)                       // a long frame must not jump the liquid
        if (fired) return
        if (holding) {
            heldFor += dt
            let v = level
            if (v < 0.5) v += (0.5 - v) * (1 - Math.exp(-dt * 10))   // arriving: first up to the half mark quickly
            v += dt * 0.5 / fillSeconds                              // then a steady rise, the longer you hold the fuller
            level = Math.min(1, v)
            if (level >= 1) { fired = true; activated() }
        } else {
            level += (goal - level) * (1 - Math.exp(-dt * (level > goal ? 7 : 9)))
            if (Math.abs(level - goal) < 0.002) level = goal
        }
    }

    FrameAnimation {
        running: !root.fired && (root.holding || Math.abs(root.level - root.goal) > 0.0005)
        onTriggered: root.step(frameTime)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
    }
}
