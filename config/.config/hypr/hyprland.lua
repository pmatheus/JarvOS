-- ╔══════════════════════════════════════════════════════════════╗
-- ║  JarvOS — Hyprland Configuration (Lua)                       ║
-- ║  github.com/pmatheus/JarvOS                                  ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Hyprland 0.56 prefers hyprland.lua over hyprland.conf and drops .conf
-- support in 0.57. The .conf tree is kept beside this file as a rollback:
-- rename this file and Hyprland falls back to it on the next start.
--
-- Add custom overrides in hyprland/custom/*.lua

local util = require("hyprland.lib.util")

require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.gestures")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom overrides, loaded last so they win (keeps upstream untouched).
util.require_dir(util.hypr_dir .. "/hyprland/custom", "hyprland.custom")

-- Keybinds feed the QuickShell cheatsheet through a JSON sidecar. Flush after
-- custom/ so overrides land in the cheatsheet too.
require("hyprland.lib.keybinds").flush(
    util.expand("~/.local/state/quickshell/user/generated/keybinds.json"))
