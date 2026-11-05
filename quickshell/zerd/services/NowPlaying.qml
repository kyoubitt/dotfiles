pragma Singleton

import QtQuick
import Quickshell
import qs.services

// What the bar, the lock screen and the widgets should show as "playing": Orbit's own player when it has a song
// (it has no MPRIS entry), otherwise whatever MPRIS offers. Orbit hands over its player object when it starts.
Singleton {
    id: root

    property var orbit: null                  // an object shaped like an MPRIS player (title, artist, art, length, position, isPlaying, next(), ...)
    readonly property bool orbitHas: root.orbit !== null && (root.orbit.trackTitle ?? "") !== ""
    readonly property var mpris: MprisController.activePlayer
    // Orbit wins unless the Spotify app (or another player) is the one making sound and Orbit is silent.
    // Orbit speaks for the shell only while it is actually playing, or when there is no other player at all: a song it
    // merely remembers never hides what another player (the Spotify app, a browser) is doing
    readonly property bool useOrbit: root.orbitHas && (root.orbit.isPlaying || !root.mpris)
    readonly property var player: root.useOrbit ? root.orbit : root.mpris
    readonly property bool isPlaying: root.useOrbit ? root.orbit.isPlaying : MprisController.isPlaying

    // the same small record MprisController keeps, from whichever player is in use
    readonly property var activeTrack: root.useOrbit
        ? ({ uniqueId: -1, artUrl: root.orbit.trackArtUrl ?? "", title: root.orbit.trackTitle ?? "", artist: root.orbit.trackArtist ?? "", album: "" })
        : MprisController.activeTrack
    readonly property bool canGoNext: root.useOrbit ? true : (MprisController.canGoNext ?? true)
    readonly property bool canGoPrevious: root.useOrbit ? true : (MprisController.canGoPrevious ?? true)

    function togglePlaying(): void { if (root.useOrbit) root.orbit.togglePlaying(); else MprisController.togglePlaying() }
    function next(): void { if (root.useOrbit) root.orbit.next(); else MprisController.next() }
    function previous(): void { if (root.useOrbit) root.orbit.previous(); else MprisController.previous() }
}
