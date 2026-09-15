-- Autostart. hl.on("hyprland.start") is the exec-once equivalent: it fires at
-- compositor start, not on every config reload.
hl.on("hyprland.start", function()
    -- Cursor
    hl.exec_cmd("hyprctl dispatch workspace 1")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- Wallpaper + hypr-arch M3 color theming
    hl.exec_cmd(
        "sleep 0.5 && [ \"$(hyprctl monitors -j | jq 'length')\" -eq 1 ] && awww-daemon --format xrgb --no-cache || awww-daemon --format xrgb")
    hl.exec_cmd("~/.config/quickshell/scripts/colors/applycolor.sh")

    -- JarvOS shell (Caelestia design, horizontal top bar)
    hl.exec_cmd("systemctl --user start quickshell-jarvos.service")

    hl.exec_cmd("jarvos-migrate --adopt")

    -- First-run setup panel (no-op unless /var/lib/jarvos/first-run-pending exists)
    hl.exec_cmd("jarvos-setup --first-run")

    -- Input method
    hl.exec_cmd("fcitx5")

    -- Core components
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd(
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1 || /usr/lib/polkit-kde-authentication-agent-1 || /usr/libexec/polkit-kde-authentication-agent-1")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("hyprpm reload")

    -- Audio
    hl.exec_cmd("easyeffects --gapplication-service")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Auto-start apps
    hl.exec_cmd(
        "ferdium --enable-features=UseOzonePlatform --ozone-platform=wayland",
        { workspace = "special:ferdium silent" })
end)
