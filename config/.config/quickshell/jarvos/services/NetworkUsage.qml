pragma Singleton

import qs.config

import Quickshell
import Quickshell.Io

import Caelestia.Internal

import QtQuick

Singleton {
    id: root

    property int refCount: 0

    // Current speeds in bytes per second
    readonly property real downloadSpeed: _downloadSpeed
    readonly property real uploadSpeed: _uploadSpeed

    // Total bytes transferred since tracking started
    readonly property real downloadTotal: _downloadTotal
    readonly property real uploadTotal: _uploadTotal

    // History buffers for sparkline
    readonly property CircularBuffer downloadBuffer: _downloadBuffer
    readonly property CircularBuffer uploadBuffer: _uploadBuffer
    readonly property int historyLength: 30

    // Private properties
    property real _downloadSpeed: 0
    property real _uploadSpeed: 0
    property real _downloadTotal: 0
    property real _uploadTotal: 0

    // Previous per-interface counters: { "eno1": { rx, tx }, ... }
    property var _prev: ({})
    property real _prevTimestamp: 0
    property bool _initialized: false

    function formatBytes(bytes: real): var {
        // Handle negative or invalid values
        if (bytes < 0 || isNaN(bytes) || !isFinite(bytes)) {
            return {
                value: 0,
                unit: "B/s"
            };
        }

        if (bytes < 1024) {
            return {
                value: bytes,
                unit: "B/s"
            };
        } else if (bytes < 1024 * 1024) {
            return {
                value: bytes / 1024,
                unit: "KB/s"
            };
        } else if (bytes < 1024 * 1024 * 1024) {
            return {
                value: bytes / (1024 * 1024),
                unit: "MB/s"
            };
        } else {
            return {
                value: bytes / (1024 * 1024 * 1024),
                unit: "GB/s"
            };
        }
    }

    function formatBytesTotal(bytes: real): var {
        // Handle negative or invalid values
        if (bytes < 0 || isNaN(bytes) || !isFinite(bytes)) {
            return {
                value: 0,
                unit: "B"
            };
        }

        if (bytes < 1024) {
            return {
                value: bytes,
                unit: "B"
            };
        } else if (bytes < 1024 * 1024) {
            return {
                value: bytes / 1024,
                unit: "KB"
            };
        } else if (bytes < 1024 * 1024 * 1024) {
            return {
                value: bytes / (1024 * 1024),
                unit: "MB"
            };
        } else {
            return {
                value: bytes / (1024 * 1024 * 1024),
                unit: "GB"
            };
        }
    }

    // Virtual interfaces are excluded so only real uplink throughput is
    // counted: bridges/veth carry container traffic, VPN tunnels carry a
    // decrypted copy, and VM bridges mirror guest traffic — all of which
    // also crosses a physical NIC.
    readonly property var _virtualPrefixes: ["lo", "docker", "br-", "veth", "virbr", "vnet", "vmnet", "tailscale", "tun", "tap", "wg", "zt", "ifb", "dummy", "gre", "sit", "kube", "cni", "flannel", "cali"]

    function isPhysicalInterface(iface: string): bool {
        if (!iface || iface === "lo")
            return false;
        return !root._virtualPrefixes.some(p => iface.startsWith(p));
    }

    // Returns a map of physical interfaces to their cumulative counters:
    //   { "eno1": { rx: <bytes>, tx: <bytes> }, ... }
    function parseNetDev(content: string): var {
        const lines = content.split("\n");
        const result = {};

        for (let i = 2; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line)
                continue;

            const parts = line.split(/\s+/);
            if (parts.length < 10)
                continue;

            const iface = parts[0].replace(":", "");
            if (!root.isPhysicalInterface(iface))
                continue;

            result[iface] = {
                rx: parseFloat(parts[1]) || 0,
                tx: parseFloat(parts[9]) || 0
            };
        }

        return result;
    }

    CircularBuffer {
        id: _downloadBuffer
        capacity: root.historyLength + 1
    }

    CircularBuffer {
        id: _uploadBuffer
        capacity: root.historyLength + 1
    }

    FileView {
        id: netDevFile
        path: "/proc/net/dev"
    }

    Timer {
        interval: Config.dashboard.resourceUpdateInterval
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            netDevFile.reload();
            const content = netDevFile.text();
            if (!content)
                return;

            const cur = root.parseNetDev(content);
            const now = Date.now();

            if (!root._initialized) {
                root._prev = cur;
                root._prevTimestamp = now;
                root._initialized = true;
                return;
            }

            const timeDelta = (now - root._prevTimestamp) / 1000; // seconds
            if (timeDelta <= 0) {
                root._prev = cur;
                return;
            }

            // Sum per-interface deltas, clamping each to >= 0. A negative or
            // absent per-interface reading means that interface reset or is new
            // this tick, so it contributes nothing until its next sample.
            let rxDelta = 0;
            let txDelta = 0;
            for (const iface in cur) {
                const prev = root._prev[iface];
                if (prev === undefined)
                    continue;
                const dRx = cur[iface].rx - prev.rx;
                const dTx = cur[iface].tx - prev.tx;
                if (dRx > 0)
                    rxDelta += dRx;
                if (dTx > 0)
                    txDelta += dTx;
            }

            root._downloadSpeed = rxDelta / timeDelta;
            root._uploadSpeed = txDelta / timeDelta;

            if (isFinite(root._downloadSpeed) && root._downloadSpeed >= 0)
                _downloadBuffer.push(root._downloadSpeed);
            if (isFinite(root._uploadSpeed) && root._uploadSpeed >= 0)
                _uploadBuffer.push(root._uploadSpeed);

            // Totals accumulate the clamped deltas (monotonic).
            root._downloadTotal += rxDelta;
            root._uploadTotal += txDelta;

            root._prev = cur;
            root._prevTimestamp = now;
        }
    }
}
