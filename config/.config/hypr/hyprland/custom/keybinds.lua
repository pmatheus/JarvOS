-- ╔══════════════════════════════════════════════════════════════╗
-- ║  JarvOS Custom Keybind Overrides                             ║
-- ║  Loaded AFTER hyprland/keybinds.lua, so a repeat wins        ║
-- ╚══════════════════════════════════════════════════════════════╝
local base = require("hyprland.keybinds")
local kb, exec, shell, first_available = base.kb, base.exec, base.shell, base.first_available
local SCRIPTS = base.SCRIPTS

-- The .conf unbound a key before rebinding it. Keep that explicit: a second
-- hl.bind on an already-bound key is not guaranteed to replace the first.
hl.unbind("SUPER + Space")
hl.unbind("SUPER + Y")
hl.unbind("SUPER + W")
hl.unbind("CTRL + SUPER + ALT + Left")
hl.unbind("CTRL + SUPER + ALT + Right")

kb.page("")
kb.section("Overrides")

-- Launcher: Super+Space opens Caelestia launcher (with file search + modifier actions)
kb.bind({ mods = { "Super" }, key = "Space", desc = "Launcher", dispatch = shell("launcher") })

-- Move togglefloating to Super+Y (upstream had layoutmsg togglesplit there)
kb.bind({ mods = { "Super" }, key = "Y", desc = "Float/Tile", dispatch = hl.dsp.window.float({ action = "toggle" }) })

-- Browser priority: Google Chrome first
kb.bind({ mods = { "Super" }, key = "W", desc = "Browser",
          dispatch = first_available("google-chrome-stable", "zen-browser", "firefox", "brave", "chromium",
                                     "microsoft-edge-stable", "opera") })

kb.section("MAS-Hunt Lab")
kb.bind({ mods = { "Super", "Alt" }, key = "1", desc = "DC01 (RDP)", dispatch = exec(SCRIPTS .. "/rdp-lab.sh dc01") })
kb.bind({ mods = { "Super", "Alt" }, key = "2", desc = "WS01 (RDP)", dispatch = exec(SCRIPTS .. "/rdp-lab.sh ws01") })
kb.bind({ mods = { "Super", "Alt" }, key = "3", desc = "WS02 (RDP)", dispatch = exec(SCRIPTS .. "/rdp-lab.sh ws02") })

kb.section("Window")
-- Move focused window to adjacent workspace, matching Ctrl+Super+Left/Right navigation
kb.bind({ mods = { "Ctrl", "Super", "Alt" }, key = "Left",  desc = "Move window to previous workspace",
          dispatch = hl.dsp.window.move({ workspace = "r-1" }) })
kb.bind({ mods = { "Ctrl", "Super", "Alt" }, key = "Right", desc = "Move window to next workspace",
          dispatch = hl.dsp.window.move({ workspace = "r+1" }) })

kb.section("Network")
-- Network settings GUI (nm-connection-editor); reapplies edits to live devices on close
kb.bind({ mods = { "Super", "Shift" }, key = "N", desc = "Network settings (GUI)",
          dispatch = exec(SCRIPTS .. "/network-settings.sh") })
