import QtQuick
import QtTest
import "../../modules/sessionScreen"

// Run from quickshell/zerd:
//   QT_QPA_PLATFORM=offscreen qmltestrunner -input scripts/tests/tst_exitfx.qml -import scripts/tests/stubs
Item {
    id: top
    width: 1280; height: 720
    Component { id: comp; ExitFx { anchors.fill: parent } }
    SignalSpy { id: fireSpy; signalName: "fire" }
    SignalSpy { id: doneSpy; signalName: "finished" }

    TestCase {
        name: "ExitFx"
        when: windowShown
        property var fx
        function init() {
            fx = createTemporaryObject(comp, top)
            fireSpy.target = fx; fireSpy.clear()
            doneSpy.target = fx; doneSpy.clear()
        }
        // the fired capsule: 144 x 196 with its top left at (x, y)
        function go(kind, x, y) { fx.begin(kind, "#f2766d", "power_settings_new", "Shut down", x, y, 144, 196, 40) }
        function part(name) { const l = findChild(fx, name); verify(l !== null, "no layer " + name); return l }
        function near(a, b, tol, what) { verify(Math.abs(a - b) <= tol, what + ": " + a + " vs " + b) }

        function test_idle_draws_nothing() {
            compare(fx.t, -1)
            verify(!fx.visible)
            verify(!fx.covered)
        }

        function test_the_command_goes_out_well_inside_900_ms() {
            for (const k of ["fade", "sleep", "crt"]) {
                fx.cancel()
                fx.kind = k
                verify(fx.fireAt <= 800, k + " fires at " + fx.fireAt)
                fireSpy.clear()
                const t0 = Date.now()
                go(k, 1000, 400)
                tryVerify(function () { return fireSpy.count === 1 }, 1500)
                verify(Date.now() - t0 < 1000, k + " took " + (Date.now() - t0) + " ms")
                wait(150)
                compare(fireSpy.count, 1)           // only once
            }
        }

        function test_command_is_not_held_back_by_the_hold() {
            // fire comes at the end of the effect; the hold and the wake come after it
            for (const k of ["fade", "sleep", "crt"]) {
                fx.kind = k
                verify(fx.fireAt < fx.fireAt + fx.holdMs && fx.holdMs >= 1500, k)
            }
        }

        function test_flood_starts_as_the_capsule_and_covers_every_corner() {
            const spots = [[10, 10], [1100, 10], [10, 500], [1100, 500], [570, 260]]
            for (const s of spots) {
                fx.cancel()
                go("fade", s[0], s[1])
                fx.seek(0)
                const f = part("flood")
                near(f.x, s[0], 0.5, "starts at the capsule x")
                near(f.y, s[1], 0.5, "starts at the capsule y")
                near(f.width, 144, 0.5, "starts at the capsule width")
                near(f.height, 196, 0.5, "starts at the capsule height")
                near(f.radius, 40, 0.5, "starts with the capsule radius")
                fx.seek(fx.floodMs - 0.5)
                const cx = f.x + f.width / 2, cy = f.y + f.height / 2
                near(cx, s[0] + 72, 0.5, "grows around the capsule centre x")
                near(cy, s[1] + 98, 0.5, "grows around the capsule centre y")
                const r = Math.min(f.width, f.height) / 2
                for (const c of [[0, 0], [1280, 0], [0, 720], [1280, 720]])
                    verify(Math.hypot(c[0] - cx, c[1] - cy) <= Math.min(r, f.radius) + 0.5, "corner " + c + " from " + s + " is outside the flood")
                fx.seek(fx.floodMs)
                verify(fx.covered)
                verify(!part("flood").visible)         // handed over to the solid layer
            }
        }

        function test_fade_goes_from_the_colour_to_black() {
            go("fade", 500, 300)
            fx.seek(fx.floodMs)
            const s = part("solid")
            near(s.color.r, 0xf2 / 255, 0.01, "full colour when the flood ends")
            fx.seek(fx.fireAt)
            near(s.color.r + s.color.g + s.color.b, 0, 0.01, "black when the command goes out")
            verify(s.visible)
        }

        function test_sleep_dims_to_near_black_and_the_moon_ends_in_the_middle() {
            go("sleep", 300, 300)
            const g = part("glyph")
            fx.seek(0)
            near(g.x + g.width / 2, 372, 1.5, "moon starts on the capsule icon x")
            near(g.y + g.height / 2, 300 + 196 * 77 / 196, 1.5, "moon starts on the capsule icon y")
            fx.seek(fx.floodMs)
            near(g.x + g.width / 2, 640, 1.5, "moon x")
            near(g.y + g.height / 2, 360, 1.5, "moon y")
            near(g.width, 128, 1, "moon size")
            fx.seek(fx.fireAt)
            const c = part("solid").color
            verify(c.r < 0.05 && c.g < 0.05 && c.b < 0.06, "near black: " + c)
            verify(c.r + c.g + c.b > 0, "not pure black")
            // it breathes: the opacity is not the same at the top and bottom of a breath
            fx.seek(fx.floodMs + 1600); const a = g.opacity
            fx.seek(fx.floodMs + 3200); const b = g.opacity
            verify(Math.abs(a - b) > 0.05, "no breathing: " + a + " " + b)
        }

        function test_crt_collapses_to_a_line_then_a_dot_then_black() {
            go("crt", 500, 300)
            const sheet = part("sheet")
            fx.seek(fx.floodMs)
            near(sheet.width, 1280, 0.5, "starts as the full screen, width")
            near(sheet.height, 720, 0.5, "starts as the full screen, height")
            fx.seek(fx.floodMs + 0.42 * fx.tailMs)
            near(sheet.width, 1280, 1, "the line is as wide as the screen")
            near(sheet.height, 3, 0.5, "the line is 3 px tall")
            verify(sheet.color.r > 0.99 && sheet.color.g > 0.99 && sheet.color.b > 0.99, "the line is white-hot: " + sheet.color)
            near(sheet.y + sheet.height / 2, 360, 1, "the line is in the middle")
            verify(part("bloom").visible)
            fx.seek(fx.floodMs + 0.73 * fx.tailMs)
            near(sheet.width, 6, 0.5, "the dot is 6 px wide")
            near(sheet.height, 6, 0.5, "the dot is 6 px tall")
            near(sheet.x + sheet.width / 2, 640, 1, "the dot is in the middle")
            fx.seek(fx.fireAt)
            verify(!sheet.visible, "the dot is out when the command goes out")
            const c = part("solid").color
            near(c.r + c.g + c.b, 0, 0.01, "the screen is black")
            verify(part("solid").visible)
            verify(fx.fireAt - fx.floodMs >= 450 && fx.fireAt - fx.floodMs <= 520, "the collapse itself takes about half a second")
        }

        function test_crt_is_the_only_one_with_a_sheet() {
            go("fade", 500, 300)
            fx.seek(fx.floodMs + 100)
            verify(!part("sheet").visible)
            verify(!part("bloom").visible)
        }

        function test_hold_then_wake_then_finished() {
            fx.holdMs = 200
            go("fade", 500, 300)
            tryVerify(function () { return fireSpy.count === 1 }, 1500)
            compare(doneSpy.count, 0)
            tryVerify(function () { return doneSpy.count === 1 }, 2000)
            verify(!fx.running)
            verify(!fx.visible)
            compare(fireSpy.count, 1)
        }

        function test_the_desktop_comes_back_on_wake() {
            go("sleep", 500, 300)
            fx.seek(fx.fireAt + 100)
            near(part("solid").opacity, 1, 0.001, "held while the command runs")
            fx.seek(fx.fireAt + fx.holdMs + fx.wakeMs / 2)
            near(part("solid").opacity, 0.5, 0.01, "half way back")
            fx.seek(fx.totalMs)
            compare(doneSpy.count, 1)
        }

        function test_wake_now_skips_the_hold() {
            go("sleep", 500, 300)
            fx.seek(fx.fireAt + 100)
            fx.wakeNow()
            tryVerify(function () { return doneSpy.count === 1 }, 800)
        }

        function test_cancel_means_no_command() {
            go("crt", 500, 300)
            wait(120)
            fx.cancel()
            wait(900)
            compare(fireSpy.count, 0)
            compare(doneSpy.count, 0)
            compare(fx.t, -1)
        }
    }
}
