import QtQuick
import QtTest

Item {
    id: top
    width: 300; height: 300
    Component { id: comp; HoldLogic { width: 200; height: 200; weight: 1 } }
    SignalSpy { id: fireSpy; signalName: "activated" }
    SignalSpy { id: tapSpy; signalName: "tapped" }

    TestCase {
        name: "Hold"
        when: windowShown
        property var h
        function init() {
            h = createTemporaryObject(comp, top)
            fireSpy.target = h; fireSpy.clear()
            tapSpy.target = h; tapSpy.clear()
        }
        function test_hover_half() {
            mouseMove(top, 100, 100)
            tryVerify(function () { return Math.abs(h.level - 0.5) < 0.01 }, 2000)
            verify(!h.fired)
            mouseMove(top, 280, 280)
            tryVerify(function () { return h.level < 0.01 }, 2000)
        }
        function test_hold_fires() {
            mouseMove(top, 100, 100)
            tryVerify(function () { return h.level > 0.45 }, 2000)
            mousePress(top, 100, 100)
            wait(300); verify(h.level > 0.5 && h.level < 1, "filling: " + h.level); verify(!h.fired)
            wait(500); verify(h.level > 0.7 && !h.fired, "still filling: " + h.level)
            tryVerify(function () { return h.fired }, 2500)
            compare(fireSpy.count, 1)
            mouseRelease(top, 100, 100)
            wait(300)
            compare(fireSpy.count, 1)
        }
        function test_hold_from_far_fires() {      // pressed right as the pointer arrives
            mouseMove(top, 100, 100)
            mousePress(top, 100, 100)
            tryVerify(function () { return h.fired }, 3000)
            compare(fireSpy.count, 1)
            mouseRelease(top, 100, 100)
        }
        function test_click_does_not_fire() {
            mouseMove(top, 100, 100)
            tryVerify(function () { return h.level > 0.45 }, 2000)
            mousePress(top, 100, 100); wait(90); mouseRelease(top, 100, 100)
            wait(1200)
            verify(!h.fired); compare(fireSpy.count, 0); compare(tapSpy.count, 1)
            verify(Math.abs(h.level - 0.5) < 0.02, "back to half: " + h.level)
        }
        function test_short_hold_drains() {
            mouseMove(top, 100, 100)
            tryVerify(function () { return h.level > 0.45 }, 2000)
            mousePress(top, 100, 100); wait(500); var peak = h.level; mouseRelease(top, 100, 100)
            verify(peak > 0.55 && peak < 1, "peak " + peak)
            wait(1500)
            verify(!h.fired); compare(tapSpy.count, 0)
            verify(Math.abs(h.level - 0.5) < 0.02, "drained to " + h.level)
        }
        function test_resume_hold() {
            mouseMove(top, 100, 100)
            mousePress(top, 100, 100); wait(700); mouseRelease(top, 100, 100)
            mousePress(top, 100, 100)
            tryVerify(function () { return h.fired }, 3000)
            compare(fireSpy.count, 1)
            mouseRelease(top, 100, 100)
        }
        function test_key_hold() {
            h.selected = true
            tryVerify(function () { return h.level > 0.45 }, 2000)
            h.keyDown()
            tryVerify(function () { return h.fired }, 3000)
            compare(fireSpy.count, 1)
            h.keyUp()
        }
        function test_hold_with_jitter_inside() {
            mouseMove(top, 100, 100)
            mousePress(top, 100, 100)
            for (var i = 0; i < 12; i++) { wait(60); mouseMove(top, 100 + (i % 3) * 6, 100 - (i % 2) * 5) }
            tryVerify(function () { return h.fired }, 3000)
            compare(fireSpy.count, 1)
            mouseRelease(top, 100, 100)
        }
        function test_hold_slides_off_then_released() {
            // pressing, dragging off the capsule and letting go outside must not fire and must drain
            mouseMove(top, 100, 100)
            mousePress(top, 100, 100); wait(400)
            mouseMove(top, 290, 290); wait(100)
            mouseRelease(top, 290, 290)
            wait(1500)
            verify(!h.fired); verify(h.level < 0.02, "level " + h.level)
        }
    }
}
