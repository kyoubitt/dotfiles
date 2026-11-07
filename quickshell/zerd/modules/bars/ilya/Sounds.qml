pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import qs.modules.common as Common
import qs.services as Svc

Item {
    id: root

    readonly property string soundsDir: Caching.serpantinumDir + "/assets/sounds/"

    property var activeHandles: ({})
    property int nextHandleId: 1

    property var _pendingQueue: []

    // Settings > Sounds: bars.sounds.enable and bars.sounds.volume (0 to 100)
    readonly property var cfg: Common.Config.options?.bars?.sounds ?? ({})
    readonly property bool isMuted: !(cfg.enable ?? true) || Svc.Notifications.silent
    readonly property real masterVolume: Math.max(0.0, Math.min(1.0, (cfg.volume ?? 60) / 100.0))

    // one sound per file within 120 ms and any sound within 35 ms, so a fast run of clicks never stacks
    property var _lastByFile: ({})
    property double _lastAny: 0
    function _allowed(path) {
        const now = Date.now();
        if (now - root._lastAny < 35) return false;
        if (now - (root._lastByFile[path] ?? 0) < 120) return false;
        root._lastAny = now;
        root._lastByFile[path] = now;
        return true;
    }

    // popups, new notifications and volume changes, as in his shell
    function popupOpened() { root.playSfx("guide/barconfig/in.wav", 0.8); }
    function popupClosed() { root.playSfx("guide/barconfig/out.wav", 0.8); }

    Connections {
        target: Svc.Notifications
        function onNotify(notification) { root.playSfx("notifications/Sine.wav", 0.9); }
    }
    property real _lastVol: -1
    Connections {
        target: Svc.Audio.sink?.audio ?? null
        function onVolumeChanged() {
            const v = Svc.Audio.sink?.audio?.volume ?? 0;
            if (root._lastVol >= 0 && Math.abs(v - root._lastVol) > 0.004) root.playSfx("system/quick_click.wav", 0.5);
            root._lastVol = v;
        }
    }

    function play(filePath, volume, duration, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return;
        if (!filePath || filePath.trim() === "") return;
        if (overrideSfxBlock !== true && !root._allowed(filePath)) return;
        let vol = volume === undefined ? 1.0 : Math.max(0.0, Math.min(2.0, volume));
        let finalVol = overrideSfxBlock === true ? vol : (vol * root.masterVolume);
        let dur = duration === undefined ? 0 : duration;
        root._pendingQueue.push({ filePath: filePath, volume: finalVol, duration: dur });
        Qt.callLater(root._drainQueue);
    }

    function playSfx(filename, volume, duration, overrideSfxBlock) {
        root.play(root.soundsDir + filename, volume, duration, overrideSfxBlock);
    }

    function _drainQueue() {
        let q = root._pendingQueue;
        root._pendingQueue = [];
        for (let i = 0; i < q.length; i++) {
            root._reallyPlay(q[i].filePath, q[i].volume, q[i].duration);
        }
    }

    function _reallyPlay(filePath, vol, dur) {
        let cleanPath = filePath.startsWith("file://") ? filePath.substring(7) : filePath;
        let propsJson = "{\"application.id\":\"serpantinum-sfx\",\"application.name\":\"serpantinum-sfx\",\"media.role\":\"event\"}";
        try {
            if (dur > 0) {
                let escaped = cleanPath.replace(/'/g, "'\\''");
                Quickshell.execDetached(["sh", "-c",
                    "exec timeout " + dur + " pw-play -P '" + propsJson + "' --volume=" + vol + " '" + escaped + "' >/dev/null 2>&1"]);
            } else {
                Quickshell.execDetached(["pw-play", "-P", propsJson, "--volume=" + vol.toString(), cleanPath]);
            }
        } catch(e) {}
    }

    Component {
        id: stoppableProcess
        Process {
            property int handleId: -1
            stdinEnabled: false
        }
    }

    function playUntilStopped(filenameOrPath, volume, loop, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return -1;
        let vol = Math.max(0.0, Math.min(2.0, volume === undefined ? 1.0 : volume));
        let finalVol = overrideSfxBlock === true ? vol : (vol * root.masterVolume);
        let doLoop = loop === true;
        let cleanPath = (filenameOrPath.startsWith("/") || filenameOrPath.startsWith("file://")) ?
            (filenameOrPath.startsWith("file://") ? filenameOrPath.substring(7) : filenameOrPath) :
            (root.soundsDir + filenameOrPath);
        let volFlag = "--volume=" + finalVol;

        let id = root.nextHandleId++;
        let sfxProps = "-P '{\"application.id\":\"serpantinum-sfx\",\"application.name\":\"serpantinum-sfx\",\"media.role\":\"event\"}' ";

        let script;
        if (doLoop) {
            script =
                "trap 'kill $CPID 2>/dev/null; exit' TERM; " +
                "while :; do pw-play " + sfxProps + volFlag + " '" + cleanPath + "' & CPID=$!; wait $CPID; done";
        } else {
            script = "exec pw-play " + sfxProps + volFlag + " '" + cleanPath + "'";
        }

        let proc = stoppableProcess.createObject(root, {
            "command": ["sh", "-c", script],
            "handleId": id
        });
        proc.running = true;

        proc.exited.connect(function() {
            delete root.activeHandles[id];
            proc.destroy();
        });

        root.activeHandles[id] = proc;
        return id;
    }

    function stopSfx(handleId) {
        let entry = root.activeHandles[handleId];
        if (!entry) return;
        entry.running = false;
        delete root.activeHandles[handleId];
    }

    function stopAllSfx() {
        for (let id in root.activeHandles) {
            root.activeHandles[id].running = false;
        }
        root.activeHandles = ({});
    }
}
