-- Touchpad/trackpad gesture support
hl.config({
    gestures = {
        workspace_swipe_distance                 = 700,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
    },
})

-- 4 fingers horizontal — switch workspace
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- 3 fingers up — toggle special workspace
hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "special" })

-- 3 fingers down — toggle special workspace (alternate)
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace"),
})
