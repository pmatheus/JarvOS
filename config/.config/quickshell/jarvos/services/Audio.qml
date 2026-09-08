pragma Singleton

import qs.config
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

import "../utils/cava.js" as CavaParser

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    // The visualiser feed, ported from caelestia's C++ CavaProvider: the
    // cava CLI runs with a raw-ascii output config and frames are parsed in
    // utils/cava.js. Refs keep it running only while consumers are mounted
    // (the ServiceRef contract from the C++ port). BPM tracking was dropped
    // in this port — see docs/decisions/2026-09-04.
    readonly property alias cava: cavaImpl

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || Config.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || Config.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || Config.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || Config.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(Config.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        // Try application name first, then description, then name
        return stream.applicationName || stream.description || stream.name || qsTr("Unknown Application");
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && Config.utilities.toasts.audioOutputChanged)
            Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && Config.utilities.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    Component.onCompleted: {
        // Write the cava conf before any watcher can mount: setText is
        // async, and spawning cava against an unflushed conf exits silently.
        root.writeCavaConf();
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            const newSinks = [];
            const newSources = [];
            const newStreams = [];

            for (const node of Pipewire.nodes.values) {
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }

            root.sinks = newSinks;
            root.sources = newSources;
            root.streams = newStreams;
        }
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    property QtObject cavaImpl: QtObject {
        id: cavaImpl

        property int bars: Config.services.visualiserBars
        property var values: []
        property var _refs: []
        property bool _running: false

        onBarsChanged: {
            cavaProc.running = false;
            root.writeCavaConf();
        }

        function startProc(): void {
            if (!cavaProc.running)
                root.writeCavaConf();
        }

        function ref(sender): void {
            if (_refs.includes(sender))
                return;
            _refs.push(sender);
            if (_refs.length === 1)
                startProc();
        }

        function unref(sender): void {
            const index = _refs.indexOf(sender);
            if (index === -1)
                return;
            _refs.splice(index, 1);
            if (_refs.length === 0)
                cavaProc.running = false;
        }
    }

    // Quickshell Processes only spawn when declared at this level: as named
    // properties on a nested property-QtObject they silently never start.
    property Timer cavaRestart: Timer {
        interval: 500
        onTriggered: root.cavaImpl.startProc()
    }

    property FileView cavaConf: FileView {
        path: `${Paths.state}/cava.conf`
        onSaved: {
            if (root.cavaImpl._refs.length > 0)
                cavaProc.running = true;
        }
    }

    property Process cavaProc: Process {
        command: ["cava", "-p", `${Paths.state}/cava.conf`]
        stdout: SplitParser {
            onRead: data => {
                const frame = CavaParser.parseFrame(data, 100, root.cavaImpl.bars);
                if (frame)
                    root.cavaImpl.values = frame;
            }
        }
        onExited: {
            if (root.cavaImpl._refs.length > 0)
                root.cavaRestart.restart();
        }
    }

    function writeCavaConf(): void {
        // FileView clears its internal path when the initial read fails (the
        // conf does not exist before the first write), so re-assert it or
        // setText fails with "no path specified".
        cavaConf.path = `${Paths.state}/cava.conf`;
        cavaConf.setText(`[general]
bars = ${root.cavaImpl.bars}
framerate = 30
noise_reduction = 0.85
stereo = false

[input]
method = pipewire
source = auto
channels = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 32
`);
    }
}
