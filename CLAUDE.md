# CLAUDE.md

## Overview

JarvOS is an Arch Linux dotfiles repository for a desktop environment using:
- **Hyprland** (Wayland compositor) with modular config split
- **QuickShell** (Qt/QML desktop shell) — the **JarvOS shell** (Caelestia-based)
- **Fish shell** with Starship prompt

## Architecture

### Hyprland Config (Modular)
`config/.config/hypr/hyprland.conf` sources individual config files:
- `general.conf` — gaps, borders, dwindle layout
- `animations.conf` — bezier curves and animation assignments
- `decoration.conf` — blur, shadows, rounding, opacity
- `gestures.conf` — touchpad gestures
- `group.conf` — window grouping with gradient tabs
- `input.conf` — keyboard, mouse, touchpad settings
- `misc.conf` — VRR, tearing, session lock
- `rules.conf` — window, workspace, and layer rules
- `keybinds.conf` — all keyboard shortcuts
- `colors.conf` — theme colors (auto-generated from wallpaper)
- `execs.conf` — startup applications
- `custom/*.conf` — user overrides

### QuickShell — JarvOS Shell (ACTIVE)

**Entry:** `config/.config/quickshell/jarvos/shell.qml`
**Launched by:** `qs -p ~/.config/quickshell/jarvos/shell.qml` (in `execs.conf`)

The JarvOS shell is built on the Caelestia design system. The `caelestia:` namespace
in keybinds is a protocol name, not a separate shell.

**Core modules** (in `jarvos/modules/`):
- `background/` — wallpaper layers, desktop clock, audio visualizer
- `drawers/` — panel system: Drawers.qml manages all slide-in panels
  - `Panels.qml` — positions launcher, dashboard, session, sidebar, OSD, notifications, utilities, popouts
  - `Interactions.qml` — hover/drag logic for showing/hiding panels
  - `Backgrounds.qml` — Shape paths for panel background rendering
- `bar/` — horizontal top bar (workspaces, window info, system tray, clock)
- `launcher/` — Spotlight-style app/file search (Super+Space)
  - `Content.qml` — search bar + results layout
  - `AppList.qml` — combined app + file search with fuzzy matching
  - `ContentList.qml` — list view with state-based delegates (apps, actions, calc, scheme, wallpapers)
  - `services/` — Apps, FileSearch, Actions, Schemes, M3Variants singletons
- `dashboard/` — top panel with media, weather, performance, lyrics
- `session/` — logout/shutdown/reboot menu (right side)
- `sidebar/` — notification sidebar (right side)
- `osd/` — on-screen display for volume/brightness
- `notifications/` — notification popups
- `controlcenter/` — full settings app with nav rail (appearance, audio, bluetooth, network, launcher, dashboard)
- `lock/` — lock screen with PAM authentication
- `areapicker/` — screenshot region selector
- `cheatsheet/` — keyboard shortcut overlay
- `utilities/` — utility cards + toast notifications

**Services** (in `jarvos/services/`): Audio, Brightness, Colours, GameMode, Hypr,
Network, Nmcli, Notifs, Players, Recorder, Screens, SystemUsage, Time,
Visibilities, VPN, Wallpapers, Weather, and more.

**Components** (in `jarvos/components/`): Reusable QML components — Anim, StyledRect,
StyledText, MaterialIcon, controls/, containers/, effects/.

**Config** (in `jarvos/config/`): Centralized config singletons — Config.qml loads
Appearance, Bar, Launcher, Dashboard, Lock, OSD, Sidebar, etc.

### Legacy Caelestia Shell (DEPRECATED — do not modify)

`config/.config/quickshell/shell.qml` and `config/.config/quickshell/modules/` contain
the old Caelestia shell with 19 lazy-loaded modules. This is **not running** and exists
only as reference. All new work goes in `jarvos/`.

### Installer
`install.sh` handles:
- Package installation via yay
- Python venv setup for QuickShell
- System services, groups, permissions
- SDDM and GRUB themes
- Supports `--minimal` flag to skip boot theming

## Key Patterns

- Custom overrides go in `hyprland/custom/*.conf` (not tracked)
- `monitors.conf` is per-machine (created by installer if missing)
- Layer rules use `quickshell:` namespace prefix
- Special workspaces: spotify, ferdium, calc, sysmon
- Colors auto-generated from wallpaper via `matugen` / `kde-material-you-colors`
- Keybinds dispatch via `global, caelestia:<name>` — handled by `jarvos/modules/Shortcuts.qml`
- **Two copies of config**: repo (`JarvOS/config/.config/quickshell/jarvos/`) and live (`~/.config/quickshell/jarvos/`). Edit both when making changes, or copy after editing repo.

## Development Notes

- This is a dotfiles repo, not a software project — no build/test commands
- Changes should respect modular config architecture
- When modifying keybinds, keep `# [hidden]` annotations for cheatsheet filtering
- QuickShell QML follows `.qmlformat.ini` (4-space indent, 110 char max)
- Panel positioning is controlled by anchors in `Panels.qml`, background shapes in `Backgrounds.qml`, and interaction zones in `Interactions.qml` — all three must stay in sync
- The launcher uses a Spotlight-style layout: search bar on top, results expand downward, empty until user types
