-- ╔══════════════════════════════════════════════════════════════╗
-- ║  JarvOS — Keybindings (Caelestia Shell)                      ║
-- ║  hidden = true keeps a bind off the cheatsheet               ║
-- ║  kb.page / kb.section are the old #! / ##! headings          ║
-- ╚══════════════════════════════════════════════════════════════╝
local kb   = require("hyprland.lib.keybinds")
local util = require("hyprland.lib.util")

local SCRIPTS = "~/.config/hypr/hyprland/scripts"
local COLORS  = "~/.config/quickshell/scripts/colors"

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function shell(name)
    return hl.dsp.global("caelestia:" .. name)
end

kb.page("")
kb.section("Shell")

-- Super+Space — launcher (Caelestia search/launcher)
kb.bind({ mods = { "Super" }, key = "Space", desc = "Launcher", dispatch = shell("launcher") })

-- Panels
kb.bind({ mods = { "Super" }, key = "N", desc = "Notification sidebar", dispatch = shell("sidebar") })
kb.bind({ mods = { "Super" }, key = "K", desc = "All panels",           dispatch = shell("showall") })
kb.bind({ mods = { "Super" }, key = "D", desc = "Dashboard",            dispatch = shell("dashboard") })
kb.bind({ mods = { "Super" }, key = "I", desc = "Settings",             dispatch = shell("controlCenter") })

-- Volume
kb.bind({ key = "XF86AudioRaiseVolume", hidden = true, opts = { locked = true, repeating = true },
          dispatch = exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+") })
kb.bind({ key = "XF86AudioLowerVolume", hidden = true, opts = { locked = true, repeating = true },
          dispatch = exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-") })
kb.bind({ key = "XF86AudioMute",    hidden = true, opts = { locked = true },
          dispatch = exec("wpctl set-mute @DEFAULT_SINK@ toggle") })
kb.bind({ key = "XF86AudioMicMute", hidden = true, opts = { locked = true },
          dispatch = exec("wpctl set-mute @DEFAULT_SOURCE@ toggle") })
kb.bind({ mods = { "Alt" }, key = "XF86AudioMute", hidden = true, opts = { locked = true },
          dispatch = exec("wpctl set-mute @DEFAULT_SOURCE@ toggle") })
kb.bind({ mods = { "Super" }, key = "Page_Up",   desc = "Volume up",   opts = { repeating = true },
          dispatch = exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+") })
kb.bind({ mods = { "Super" }, key = "Page_Down", desc = "Volume down", opts = { repeating = true },
          dispatch = exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") })
kb.bind({ mods = { "Super", "Shift" }, key = "M", desc = "Mute toggle", opts = { locked = true },
          dispatch = exec("wpctl set-mute @DEFAULT_SINK@ toggle") })
kb.bind({ mods = { "Super", "Alt" },   key = "M", desc = "Mic toggle",  opts = { locked = true },
          dispatch = exec("wpctl set-mute @DEFAULT_SOURCE@ toggle") })

-- Brightness (via Caelestia OSD)
kb.bind({ key = "XF86MonBrightnessUp",   hidden = true, opts = { locked = true }, dispatch = shell("brightnessUp") })
kb.bind({ key = "XF86MonBrightnessDown", hidden = true, opts = { locked = true }, dispatch = shell("brightnessDown") })

-- Wallpaper & theming
kb.bind({ mods = { "Super", "Ctrl", "Alt" }, key = "W", desc = "Change wallpaper", dispatch = exec(COLORS .. "/switchwall.sh") })
kb.bind({ mods = { "Super", "Ctrl", "Alt" }, key = "T", desc = "Random wallpaper", dispatch = exec(SCRIPTS .. "/random-wallpaper.sh") })
kb.bind({ mods = { "Super", "Ctrl", "Alt" }, key = "Y", desc = "Re-apply colors",  dispatch = exec(COLORS .. "/applycolor.sh") })
kb.bind({ mods = { "Super", "Ctrl", "Alt" }, key = "R", desc = "Restart shell",
          dispatch = exec("systemctl --user restart quickshell-jarvos.service") })

-- Notifications
kb.bind({ mods = { "Ctrl", "Alt" }, key = "C", desc = "Clear notifications", opts = { locked = true },
          dispatch = shell("clearNotifs") })

kb.bind({ mods = { "Super" },          key = "U", desc = "Utilities panel",       dispatch = shell("utilities") })
kb.bind({ mods = { "Super", "Shift" }, key = "O", desc = "Volume/brightness OSD", dispatch = shell("osd") })

kb.section("Utilities")

-- Screenshots (grimblast + satty)
kb.bind({ mods = { "Super" },          key = "Print", desc = "Snip + edit",       dispatch = exec(SCRIPTS .. "/hypr-snip.sh") })
kb.bind({ mods = { "Super", "Shift" }, key = "Print", desc = "Snip to clipboard",
          dispatch = exec("grimblast --freeze save area - | wl-copy") })
kb.bind({ mods = { "Super", "Shift" }, key = "S",     desc = "Screen snip",       dispatch = exec(SCRIPTS .. "/hypr-snip.sh") })
kb.bind({ key = "Print", desc = "Full screenshot", opts = { locked = true },
          dispatch = exec("grim - | wl-copy") })
kb.bind({ mods = { "Ctrl" }, key = "Print", desc = "Save screenshot", opts = { locked = true },
          dispatch = exec("mkdir -p $(xdg-user-dir PICTURES)/Screenshots && grim $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png") })

-- Tools
kb.bind({ mods = { "Super" }, key = "H",      desc = "Cheatsheet", dispatch = shell("cheatsheet") })
kb.bind({ mods = { "Super" }, key = "V",      desc = "Clipboard",
          dispatch = exec("pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy") })
kb.bind({ mods = { "Super" }, key = "Period", desc = "Emoji",
          dispatch = exec("pkill fuzzel || " .. SCRIPTS .. "/fuzzel-emoji.sh copy") })

kb.section("Screen")
kb.bind({ mods = { "Super" }, key = "Minus", desc = "Zoom out", opts = { repeating = true },
          dispatch = exec(SCRIPTS .. "/zoom.sh decrease 0.1") })
kb.bind({ mods = { "Super" }, key = "Equal", desc = "Zoom in",  opts = { repeating = true },
          dispatch = exec(SCRIPTS .. "/zoom.sh increase 0.1") })

kb.page("")
kb.section("Window")

-- Mouse
kb.bind({ mods = { "Super" }, key = "mouse:272", hidden = true, opts = { drag = true }, dispatch = hl.dsp.window.drag() })
kb.bind({ mods = { "Super" }, key = "mouse:274", hidden = true, opts = { drag = true }, dispatch = hl.dsp.window.drag() })
kb.bind({ mods = { "Super" }, key = "mouse:273", hidden = true, opts = { drag = true }, dispatch = hl.dsp.window.resize() })

kb.bind({ mods = { "Super" }, key = "Q",  desc = "Close",  dispatch = hl.dsp.window.close() })
kb.bind({ mods = { "Alt" },   key = "F4", hidden = true,   dispatch = hl.dsp.window.close() })

-- Layout
kb.bind({ mods = { "Super" },          key = "Y", desc = "Float/Tile", dispatch = hl.dsp.window.float({ action = "toggle" }) })
kb.bind({ mods = { "Super" },          key = "F", desc = "Maximize",   dispatch = hl.dsp.window.fullscreen(1) })
kb.bind({ mods = { "Super", "Shift" }, key = "F", desc = "Fullscreen", dispatch = hl.dsp.window.fullscreen(0) })
kb.bind({ mods = { "Super" },          key = "P", desc = "Pin",        dispatch = hl.dsp.window.pin() })

-- Focus (arrows)
local DIRS = { Left = "left", Right = "right", Up = "up", Down = "down" }
for _, d in ipairs({ "Left", "Right", "Up", "Down" }) do
    kb.bind({ mods = { "Super" }, key = d, desc = "Focus " .. DIRS[d],
              dispatch = hl.dsp.focus({ direction = DIRS[d] }) })
end

-- Move window (Alt+arrows)
for _, d in ipairs({ "Left", "Right", "Up", "Down" }) do
    kb.bind({ mods = { "Super", "Alt" }, key = d, desc = "Move " .. DIRS[d],
              dispatch = hl.dsp.window.move({ direction = DIRS[d] }) })
end

-- Groups.
-- NOTE: Super+U is declared twice, here and as "Utilities panel" above. This
-- mirrors the .conf, where the later declaration won and the utilities panel
-- bind was dead. Kept as-is rather than silently changing behaviour.
kb.bind({ mods = { "Super" }, key = "Comma", desc = "Group",   dispatch = hl.dsp.group.toggle() })
kb.bind({ mods = { "Super" }, key = "U",     desc = "Ungroup", dispatch = exec("hyprctl dispatch moveoutofgroup") })

-- Send to workspace
for i = 1, 10 do
    kb.bind({ mods = { "Super", "Shift" }, key = tostring(i % 10), hidden = true,
              desc = "Send to workspace " .. i,
              dispatch = exec(SCRIPTS .. "/workspace_action.sh movetoworkspacesilent " .. i) })
end
kb.bind({ mods = { "Super", "Shift" }, key = "S", desc = "Send to scratchpad",
          dispatch = hl.dsp.window.move({ workspace = "special", silent = true }) })

kb.bind({ mods = { "Alt" }, key = "Tab", desc = "Switch window", dispatch = hl.dsp.window.cycle_next() })
kb.bind({ mods = { "Alt" }, key = "Tab", hidden = true, dispatch = hl.dsp.window.bring_to_top() })

kb.section("Workspace")
for i = 1, 10 do
    kb.bind({ mods = { "Super" }, key = tostring(i % 10), hidden = true,
              desc = "Workspace " .. i,
              dispatch = exec(SCRIPTS .. "/workspace_action.sh workspace " .. i) })
end

kb.bind({ mods = { "Super" },         key = "Tab",   desc = "Previous workspace", dispatch = hl.dsp.focus({ workspace = "previous" }) })
kb.bind({ mods = { "Super" },         key = "S",     desc = "Scratchpad",         dispatch = hl.dsp.workspace.toggle_special() })
kb.bind({ mods = { "Ctrl", "Super" }, key = "Right", desc = "Next workspace",     dispatch = hl.dsp.focus({ workspace = "r+1" }) })
kb.bind({ mods = { "Ctrl", "Super" }, key = "Left",  desc = "Prev workspace",     dispatch = hl.dsp.focus({ workspace = "r-1" }) })

kb.bind({ mods = { "Ctrl", "Shift" }, key = "Escape", desc = "Task manager",
          dispatch = exec("pgrep btop && hyprctl dispatch togglespecialworkspace sysmon || kitty -1 fish -c btop") })

kb.page("")
kb.section("Session")
kb.bind({ mods = { "Super" },                key = "L",      desc = "Lock",         dispatch = exec("~/.config/hypr/hyprlock/lock.sh") })
kb.bind({ mods = { "Ctrl", "Alt" },          key = "Delete", desc = "Session menu", dispatch = shell("session") })
kb.bind({ mods = { "Super", "Shift" },       key = "L",      desc = "Sleep",        opts = { locked = true },
          dispatch = exec("systemctl suspend-then-hibernate") })
kb.bind({ mods = { "Super", "Ctrl", "Alt" }, key = "Delete", desc = "Shutdown",
          dispatch = exec("systemctl poweroff || loginctl poweroff") })

kb.section("Media")
kb.bind({ mods = { "Ctrl", "Super" }, key = "Space",           desc = "Play/Pause", opts = { locked = true }, dispatch = shell("mediaToggle") })
kb.bind({ key = "XF86AudioPlay",  hidden = true, opts = { locked = true }, dispatch = shell("mediaToggle") })
kb.bind({ key = "XF86AudioPause", hidden = true, opts = { locked = true }, dispatch = shell("mediaToggle") })
kb.bind({ key = "XF86AudioNext",  hidden = true, opts = { locked = true }, dispatch = shell("mediaNext") })
kb.bind({ key = "XF86AudioPrev",  hidden = true, opts = { locked = true }, dispatch = shell("mediaPrev") })

kb.section("Apps")
local function first_available(...)
    local quoted = {}
    for i, app in ipairs({ ... }) do
        quoted[i] = '"' .. app .. '"'
    end
    return exec(SCRIPTS .. "/launch_first_available.sh " .. table.concat(quoted, " "))
end

kb.bind({ mods = { "Super" }, key = "Return", desc = "Terminal",
          dispatch = first_available("kitty -1", "foot", "alacritty", "wezterm", "konsole", "kgx", "uxterm", "xterm") })
kb.bind({ mods = { "Super" }, key = "E", desc = "File manager",
          dispatch = first_available("nautilus", "thunar", "dolphin", "nemo") })
kb.bind({ mods = { "Super" }, key = "W", desc = "Browser",
          dispatch = first_available("zen-browser", "google-chrome-stable", "firefox", "brave", "chromium") })
kb.bind({ mods = { "Super" }, key = "C", desc = "Code editor",
          dispatch = first_available("code", "codium", "zed", "kate", "gnome-text-editor") })
kb.bind({ mods = { "Super" }, key = "X", desc = "Text editor", dispatch = exec("gnome-text-editor") })
kb.bind({ mods = { "Super" }, key = "B", desc = "Calculator",
          dispatch = exec("pgrep qalculate && hyprctl dispatch togglespecialworkspace calc || qalculate-gtk") })
kb.bind({ mods = { "Super" }, key = "O", desc = "Obsidian",
          dispatch = exec("obsidian -enable-features=UseOzonePlatform -ozone-platform=wayland") })
kb.bind({ mods = { "Super" }, key = "A", desc = "AI Agents", dispatch = exec("jarvos-agent-pick") })
kb.bind({ mods = { "Super" }, key = "J", desc = "Chinese Learning Scratchpad", dispatch = exec("jarvos-chinese") })
kb.bind({ mods = { "Super", "Alt" }, key = "C", desc = "Chinese Learning Scratchpad", dispatch = exec("jarvos-chinese") })
kb.bind({ mods = { "Super" }, key = "M", desc = "Spotify",
          dispatch = exec("pgrep spotify && hyprctl dispatch togglespecialworkspace spotify || spotify --enable-features=UseOzonePlatform --ozone-platform=wayland") })
kb.bind({ mods = { "Super" }, key = "Z", desc = "Ferdium",
          dispatch = exec("pgrep -f ferdium && hyprctl dispatch togglespecialworkspace ferdium || ferdium --enable-features=UseOzonePlatform --ozone-platform=wayland") })

return { kb = kb, util = util, exec = exec, shell = shell, first_available = first_available, SCRIPTS = SCRIPTS }
