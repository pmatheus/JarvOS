//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_RHI_BACKEND=vulkan
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/cheatsheet"
import Quickshell

ShellRoot {
    Background {}
    Drawers {}
    AreaPicker {}
    Cheatsheet {}

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {}
}
