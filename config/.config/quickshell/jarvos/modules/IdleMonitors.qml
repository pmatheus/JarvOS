pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Caelestia.Internal
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property bool enabled: !Config.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)

    function lockNow(): void {
        Quickshell.execDetached(["sh", "-c", "pidof hyprlock || ~/.config/hypr/hyprlock/lock.sh"]);
    }

    function unlockNow(): void {
        Quickshell.execDetached(["pkill", "hyprlock"]);
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            root.lockNow();
        else if (action === "unlock")
            root.unlockNow();
        else if (typeof action === "string")
            Hypr.dispatch(action);
        else
            Quickshell.execDetached(action);
    }

    LogindManager {
        onAboutToSleep: {
            if (Config.general.idle.lockBeforeSleep)
                root.lockNow();
        }
        onLockRequested: root.lockNow()
        onUnlockRequested: root.unlockNow()
    }

    Variants {
        model: Config.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
