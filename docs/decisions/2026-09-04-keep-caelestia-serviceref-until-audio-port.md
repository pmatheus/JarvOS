# Decision: keep Caelestia's ServiceRef until the audio services port

**Date:** 2026-09-04
**Status:** decided — Task 8 of the removal part 2 plan
**Decided by:** evidence gathered during the Caelestia removal; no code change

## Finding

`ServiceRef` is set at four sites (`Visualiser.qml`, two `Media.qml` cards,
`dash/Media.qml`) and nothing reads it — but its *side effect* is load-bearing.
The removal plan asked the question the decision doc's table could not answer.

- `Service::ref()` calls `start()` on the first ref and `unref()` calls
  `stop()` on the last (`plugin/src/Caelestia/Services/service.cpp`).
- `AudioProvider::start()` opens the PipeWire capture thread
  (`AudioCollector::instance()` + processor start); `stop()` closes it.
- So `Audio.cava.values` (Media bars) and `Audio.beatTracker.bpm` (GIF speed)
  are live exactly while the consumer components are mounted. Without a ref
  the capture thread never opens: frozen visualiser, static GIF speeds.

The lifetime behaviour matters. Deleting ServiceRef is rejected.

## Why not reimplement it now

A QML replacement cannot drive the current C++ services: `Service::ref` and
`Service::unref` are plain public methods without `Q_INVOKABLE`, invisible to
QML. The refcount can only move into QML together with services we own.

## Decision

Keep the C++ `ServiceRef` and the three `import Caelestia.Services` lines it
needs until rollout step 7 (the `CavaProvider`/`BeatTracker` port), where our
own providers get QML-reachable start/stop and the refcount lands in that
port. The spec already requires the replacement processes to start only when
something is watching and stop when nothing is, so the port inherits the
requirement rather than inventing it.
