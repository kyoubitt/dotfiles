import QtQuick
import QtTest
import "../../modules/settings/SettingsSearch.js" as Search

Item {
    readonly property var pages: [
        { name: "Bar", groups: [{ title: "Look", rows: [
            { t: "choice", label: "Bar style", hint: "Pills or strip", opts: [{ v: "a", l: "Floating" }] },
            { t: "step", label: "Bar height" }] }] },
        { name: "Controls", groups: [{ title: "Keys", rows: [{ t: "binds", label: "Keyboard shortcuts" }] }] },
        { name: "Overview", groups: [{ title: "", rows: [{ t: "overview", label: "x" }] }] }
    ]
    TestCase {
        name: "SettingsSearch"
        function test_index_and_ids() {
            const ix = Search.buildIndex(pages, [{ name: "Screenshot", key: "Mod+Shift+S" }])
            compare(ix.length, 4)                       // overview row skipped, one bind added
            compare(ix[0].id, "p0g0r0")
            compare(ix[3].id, "bind:Mod+Shift+S")
            compare(ix[3].page, 1)
        }
        function test_title_start_beats_hint() {
            const ix = Search.buildIndex(pages, [])
            const r = Search.search(ix, "bar")
            compare(r[0].label, "Bar style")
            compare(r.length, 2)
        }
        function test_every_word_must_match() {
            const ix = Search.buildIndex(pages, [])
            compare(Search.search(ix, "bar height").length, 1)
            compare(Search.search(ix, "bar zzz").length, 0)
            compare(Search.search(ix, "   ").length, 0)
        }
        function test_option_names_and_binds_are_found() {
            const ix = Search.buildIndex(pages, [{ name: "Screenshot", key: "Mod+Shift+S" }])
            compare(Search.search(ix, "floating")[0].label, "Bar style")
            compare(Search.search(ix, "super")[0].label, "Screenshot")
        }
    }
}
