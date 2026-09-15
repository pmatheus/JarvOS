-- ╔══════════════════════════════════════════════════════════════╗
-- ║  JarvOS — Window, Workspace & Layer Rules                    ║
-- ╚══════════════════════════════════════════════════════════════╝
-- Rules that shared a matcher in the .conf are merged into one call here.

-- ######## Global visual rules ########

-- 95% opacity on all non-fullscreen windows — the Caelestia signature look
hl.window_rule({ name = "global-opacity", match = { fullscreen = false }, opacity = "0.95 override" })

-- Force opaque on apps that need it (native transparency or visual accuracy)
hl.window_rule({
    name  = "force-opaque",
    match = { class = "foot|kitty|alacritty|org\\.quickshell|imv|swappy" },
    opaque = true,
})

-- Auto-center all floating windows (except xwayland popups)
hl.window_rule({ name = "center-floats", match = { float = true, xwayland = false }, center = true })

-- ######## Floating windows ########

local FLOAT_CLASSES = {
    "guifetch",
    "yad",
    "zenity",
    "wev",
    "org\\.gnome\\.FileRoller",
    "file-roller",
    "blueman-manager",
    "feh",
    "imv",
    "system-config-printer",
    "org\\.quickshell",
    "^(blueberry\\.py)$",
    "^(steam)$",
    "^(pavucontrol)$",
    "^(org.pulseaudio.pavucontrol)$",
    "^(nm-connection-editor)$",
    ".*plasmawindowed.*",
    "kcm_.*",
    ".*bluedevilwizard",
    "xdg.desktop.portal.gtk",
    "Windscribe",
    "com\\.github\\.GradienceTeam\\.Gradience",
}

for _, class in ipairs(FLOAT_CLASSES) do
    hl.window_rule({ name = "float-" .. class, match = { class = class }, float = true })
end

local FLOAT_TITLES = {
    ".*Welcome",
    "^(illogical-impulse Settings)$",
    -- Dialog windows
    "(Select|Open)( a)? (File|Folder)(s)?",
    "File (Operation|Upload)( Progress)?",
    ".* Properties",
    "Export Image as PNG",
    "GIMP Crash Debug",
    "Save As",
    "Library",
    "^(Open File)(.*)$",
    "^(Select a File)(.*)$",
    "^(Select file)(.*)$",
    "^(Choose wallpaper)(.*)$",
    "^(Open Folder)(.*)$",
    "^(File Upload)(.*)$",
}

for _, title in ipairs(FLOAT_TITLES) do
    hl.window_rule({ name = "float-title-" .. title, match = { title = title }, float = true })
end

-- Float + resize + center
hl.window_rule({ name = "size-pavucontrol",   match = { class = "^(pavucontrol)$" },               size = "45% 45%" })
hl.window_rule({ name = "size-pavucontrol-pa", match = { class = "^(org.pulseaudio.pavucontrol)$" }, size = "45% 45%" })
hl.window_rule({ name = "size-nm-editor",     match = { class = "^(nm-connection-editor)$" },      size = "45% 45%" })

hl.window_rule({
    name  = "nmtui",
    match = { class = "foot", title = "nmtui" },
    float = true, size = "60% 70%", center = true,
})

hl.window_rule({
    name  = "gnome-settings",
    match = { class = "org\\.gnome\\.Settings" },
    float = true, size = "70% 80%", center = true,
})

hl.window_rule({
    name  = "pavucontrol-yad",
    match = { class = "org\\.pulseaudio\\.pavucontrol|yad-icon-browser" },
    float = true, size = "60% 70%", center = true,
})

hl.window_rule({
    name  = "nwg-look",
    match = { class = "nwg-look" },
    float = true, size = "50% 60%", center = true,
})

-- No appearance — kde-material-you-colors window
hl.window_rule({
    name  = "hide-plasma-changeicons",
    match = { class = "^(plasma-changeicons)$" },
    float = true, no_initial_focus = true, move = "999999 999999",
})

-- Tiling
hl.window_rule({ name = "tile-warp", match = { class = "^dev\\.warp\\.Warp$" }, tile = true })

-- ######## Picture-in-Picture ########
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^([Pp]icture[- ]?[Ii]n[- ]?[Pp]icture)(.*)$" },
    move = "100%-w-2% 100%-w-3%", keep_aspect_ratio = true, float = true, pin = true,
})

-- ######## Creative software — force opaque ########
hl.window_rule({
    name  = "opaque-creative",
    match = { class = "krita|gimp|inkscape|darktable|resolve|kdenlive|shotcut|blender|godot" },
    opaque = true,
})

-- ######## Games ########
-- Steam, Lutris/Wine, Gamescope — tearing + idle inhibit + opaque
hl.window_rule({
    name  = "games",
    match = { class = "(steam_app_(default|[0-9]+))|gamescope" },
    opaque = true, immediate = true, idle_inhibit = "always",
})
hl.window_rule({ name = "immediate-exe",       match = { title = ".*\\.exe" },      immediate = true })
hl.window_rule({ name = "immediate-minecraft", match = { title = ".*minecraft.*" }, immediate = true })

-- Steam UI
hl.window_rule({ name = "steam-rounding", match = { class = "steam" }, rounding = 10 })
hl.window_rule({ name = "steam-friends",  match = { class = "steam", title = "Friends List" }, float = true })

-- Ueberzugpp
hl.window_rule({
    name  = "ueberzugpp",
    match = { class = "^(ueberzugpp_.*)$" },
    float = true, no_initial_focus = true,
})

-- XWayland popup cleanup
hl.window_rule({
    name  = "xwayland-popups",
    match = { xwayland = true, title = "win[0-9]+" },
    no_dim = true, no_shadow = true, rounding = 10,
})

-- ######## Special workspace rules ########
for _, ws in ipairs({ "special", "spotify", "ferdium", "calc", "sysmon" }) do
    hl.workspace_rule({ workspace = "special:" .. ws, gaps_out = 30 })
end

hl.window_rule({ name = "spotify-ws", match = { class = "spotify" }, workspace = "special:spotify" })
hl.window_rule({ name = "ferdium-ws", match = { class = "ferdium" }, workspace = "special:ferdium" })
hl.window_rule({ name = "btop-ws",    match = { class = "btop" },    workspace = "special:sysmon" })

hl.window_rule({
    name  = "qalculate",
    match = { class = "qalculate-gtk" },
    float = true, center = true, workspace = "special:calc",
})

-- Music apps → special:spotify (Caelestia pattern)
hl.window_rule({
    name  = "music-apps-ws",
    match = { class = "feishin|Supersonic|Cider|com.github.th_ch.youtube_music|Plexamp" },
    workspace = "special:spotify",
})
hl.window_rule({
    name  = "spotify-initial-ws",
    match = { initial_title = "Spotify( Free)?" },
    workspace = "special:spotify",
})

-- Communication apps → special:ferdium
hl.window_rule({
    name  = "comms-apps-ws",
    match = { class = "discord|equibop|vesktop|whatsapp" },
    workspace = "special:ferdium",
})

-- ######## Dynamic workspace gaps ########
-- Single-window workspaces use the same tight gap as the rest.
hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 2 })
hl.workspace_rule({ workspace = "f[1]s[false]",   gaps_out = 2 })

-- ######## Layer rules ########

-- Utility overlays — fade
for _, ns in ipairs({ "hyprpicker", "logout_dialog", "selection", "wayfreeze" }) do
    hl.layer_rule({ name = "fade-" .. ns, match = { namespace = ns }, animation = "fade" })
end

-- Fuzzel launcher
hl.layer_rule({ name = "launcher", match = { namespace = "launcher" }, animation = "popin 80%", blur = true })

-- QuickShell layers
hl.window_rule({ name = "quickshell-windows", match = { class = "org\\.quickshell" }, opaque = true, float = true })

hl.layer_rule({ name = "overview",         match = { namespace = "quickshell:overview" }, animation = "popin 98%", dim_around = true })
hl.layer_rule({ name = "gtk4-layer-shell", match = { namespace = "gtk4-layer-shell" },    no_anim = true })
hl.layer_rule({ name = "screen-corners",   match = { namespace = "quickshell:screenCorners" }, animation = "fade" })
hl.layer_rule({ name = "osk",              match = { namespace = "quickshell:osk" },      animation = "slide bottom" })
hl.layer_rule({ name = "dock",             match = { namespace = "quickshell:dock" },     animation = "slide bottom" })
hl.layer_rule({ name = "notif-popup",      match = { namespace = "quickshell:notificationPopup" }, animation = "fade" })
hl.layer_rule({ name = "cheatsheet",       match = { namespace = "quickshell:cheatsheet" }, dim_around = true })

-- Glassmorphism blur on bar and sidebar
hl.layer_rule({
    name  = "bar",
    match = { namespace = "quickshell:bar" },
    animation = "slide", blur = true, ignore_alpha = 0.57,
})
hl.layer_rule({
    name  = "sidebar-right",
    match = { namespace = "quickshell:sidebarRight" },
    animation = "slide right", blur = true, ignore_alpha = 0.57,
})

-- Session overlay — full blur
hl.layer_rule({
    name  = "session",
    match = { namespace = "quickshell:session" },
    blur = true, no_anim = true, ignore_alpha = 0,
})

-- Chinese Learning Scratchpad
hl.window_rule({
    name  = "chinese-scratchpad-title",
    match = { title = "^(JarvOS 华语 • Chinese Field Scratchpad).*$" },
    float = true, size = "65% 82%", center = true,
})
hl.window_rule({
    name  = "chinese-scratchpad-class",
    match = { class = "^(jarvos-chinese)$" },
    float = true, size = "65% 82%", center = true,
})
