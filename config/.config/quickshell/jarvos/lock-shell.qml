//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_RHI_BACKEND=vulkan

import "modules/lock"
import Quickshell

ShellRoot {
    Lock {
        id: lock
    }
}
