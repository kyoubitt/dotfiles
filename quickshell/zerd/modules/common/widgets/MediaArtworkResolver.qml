import QtQuick

// Stand-in for iNiR's MediaArtworkResolver (downloads and caches cover art for the
// "organic" and "album" visualizer modes). Not wired here: those modes get no art,
// the bars and wave modes are unaffected.
QtObject {
    property string sourceUrl: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string cacheDirectory: ""
    readonly property bool ready: false
    readonly property string displaySource: ""
}
