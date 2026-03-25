# CLAUDE.md

## Overview

JarvOS is an Arch Linux dotfiles repository for a desktop environment using:
- **Hyprland** (Wayland compositor) with modular config split
- **QuickShell** (Qt/QML desktop shell) with 16 lazy-loaded modules
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

### QuickShell
- Entry: `config/.config/quickshell/shell.qml`
- Modules toggled via boolean properties
- 92 reusable widgets in `modules/common/widgets/`
- 25 backend services in `services/`
- Material Design 3 theming via `Appearance.qml`

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

## Development Notes

- This is a dotfiles repo, not a software project — no build/test commands
- Changes should respect modular config architecture
- When modifying keybinds, keep `# [hidden]` annotations for cheatsheet filtering
- QuickShell QML follows `.qmlformat.ini` (4-space indent, 110 char max)
