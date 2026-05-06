<p align="center">
  <br/>
  <br/>
</p>

```
                     ██╗ █████╗ ██████╗ ██╗   ██╗ ██████╗ ███████╗
                     ██║██╔══██╗██╔══██╗██║   ██║██╔═══██╗██╔════╝
                     ██║███████║██████╔╝██║   ██║██║   ██║███████╗
                ██   ██║██╔══██║██╔══██╗╚██╗ ██╔╝██║   ██║╚════██║
                ╚█████╔╝██║  ██║██║  ██║ ╚████╔╝ ╚██████╔╝███████║
                 ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝   ╚═════╝ ╚══════╝

          ┌─────────────────────────────────────────────────────────────┐
          │  Hyprland  +  QuickShell  +  Material Design 3  +  Arch   │
          └─────────────────────────────────────────────────────────────┘
```

<p align="center">
  <em>The AI-native operating system.<br/>
  A modern Arch Linux desktop where AI agents see, interact with, and control<br/>
  every application — built on Hyprland, QuickShell, and Material Design 3.</em>
</p>

<p align="center">
  <a href="#one-line-install"><strong>Install</strong></a> &nbsp;&bull;&nbsp;
  <a href="#ai-native"><strong>AI-Native</strong></a> &nbsp;&bull;&nbsp;
  <a href="#features"><strong>Features</strong></a> &nbsp;&bull;&nbsp;
  <a href="#key-bindings"><strong>Keybindings</strong></a> &nbsp;&bull;&nbsp;
  <a href="#architecture"><strong>Architecture</strong></a> &nbsp;&bull;&nbsp;
  <a href="#credits"><strong>Credits</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch Linux"/>
  <img src="https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=black" alt="Hyprland"/>
  <img src="https://img.shields.io/badge/Wayland-FFB81C?style=for-the-badge&logo=wayland&logoColor=black" alt="Wayland"/>
  <img src="https://img.shields.io/badge/Qt_QML-41CD52?style=for-the-badge&logo=qt&logoColor=white" alt="Qt QML"/>
  <img src="https://img.shields.io/badge/Material_Design_3-757575?style=for-the-badge&logo=material-design&logoColor=white" alt="Material Design 3"/>
</p>

---

> Merges the best of [END-4/dots-hyprland](https://github.com/end-4/dots-hyprland) and [Caelestia](https://github.com/caelestia-dots/caelestia) into a unified, opinionated desktop experience — then adds an AI control layer that lets LLM agents operate it autonomously.

## AI-Native

JarvOS is the first desktop environment designed for AI agents to control. Through **[hypr-box](https://github.com/pmatheus/hypr-box)**, any LLM agent can:

- **See** the screen via per-monitor screenshots (readable by vision models)
- **Interact** with any GUI application through coordinate-based clicking and keyboard input
- **Manage** windows, workspaces, audio, wallpaper, notifications, and system state
- **Launch** applications and wait for them to appear
- **Read** screen content via OCR or multimodal vision
- **Control** QuickShell panels, media playback, DPMS, and runtime config

```bash
# Install the AI control layer
uv tool install -e hypr-box
```

**9 command groups, 40+ subcommands** — window, workspace, input, screenshot, panel, media, query, system, event. All output is structured JSON for agent consumption.

## One-Line Install

```bash
bash <(curl -s https://raw.githubusercontent.com/pmatheus/JarvOS/main/install.sh)
```

Or clone and install manually:

```bash
git clone https://github.com/pmatheus/JarvOS.git ~/JarvOS
cd ~/JarvOS
./install.sh            # Full install (GRUB + SDDM + everything)
./install.sh --minimal  # Skip GRUB/SDDM (if you already have those)
```

### Requirements
- Arch Linux or Arch-based distribution (EndeavourOS, CachyOS, etc.)
- UEFI system (for GRUB theme)
- Non-root user with sudo access

## Features

### Visual Design
- **Material Design 3** color system with dynamic wallpaper-based theming
- **Glassmorphism** blur on sidebar and overlays
- **Fluid animations** — 9 custom bezier curves for windows, workspaces, layers
- **Dynamic gap sizing** — single-window workspaces breathe with larger gaps
- **18px window rounding** with subtle shadows
- **85% inactive window opacity** with blur-through
- **6 GPU shaders** — CRT, chromatic aberration, solarized, invert, and more

### Shell Components (16 QuickShell Modules)
| Module | Description |
|--------|-------------|
| **Bar** | Per-monitor taskbar with workspaces, clock, media, battery, sys tray |
| **Sidebar Right** | Calendar, notifications, quick toggles, volume mixer, todo |
| **Overview** | Spotlight-style app launcher with search, emoji, clipboard history |
| **Notifications** | Material Design popup notifications with actions |
| **OSD** | On-screen volume and brightness indicators |
| **Media Controls** | MPRIS player control overlay |
| **Resource Monitor** | CPU, RAM, disk, network stats |
| **Weather** | Current weather widget |
| **Clock/Calendar** | Full-featured calendar and clock monitors |
| **Cheatsheet** | Keybinding reference (Super+H) |
| **Session** | Power menu with lock, logout, suspend, shutdown |
| **Screen Corners** | Hot corner detection |
| **On-Screen Keyboard** | Virtual keyboard for touch input |
| **Background Widgets** | Desktop background elements |

### Window Management
- **Window groups** with gradient tab indicators (`Super+,`)
- **Gesture support** — 4-finger swipe for workspaces, 3-finger for special workspaces
- **Special workspaces** — scratchpad, Spotify, Ferdium, calculator, system monitor
- **Smart resizing** — `Super+Alt+Arrows` for proportional resize
- **Snap-to-edge** tiling with dwindle layout
- **Picture-in-Picture** auto-positioning

### Extras
- **Lock screen** (hyprlock — Aurora Glass theme) with blurred wallpaper, glass auth card, time-aware greeting, sysline + weather chips, capslock indicator
- **SDDM theme** (Sugar Candy) for a polished login experience
- **GRUB theme** (Particle) for boot screen aesthetics
- **Fish shell** with Starship prompt, fzf, and zoxide
- **26 curated wallpapers** with automatic M3 color extraction

## Key Bindings

### Essential
| Shortcut | Action |
|----------|--------|
| `Super` | Overview / App launcher |
| `Super+Space` | Spotlight search |
| `Super+Return` | Terminal |
| `Super+E` | File manager |
| `Super+W` | Browser |
| `Super+Q` | Close window |

### Shell Panels
| Shortcut | Action |
|----------|--------|
| `Super+N` | Toggle sidebar |
| `Super+H` | Toggle cheatsheet |
| `Super+K` | Toggle on-screen keyboard |
| `Super+I` | Settings |
| `Ctrl+Alt+Delete` | Session menu |

### Window Management
| Shortcut | Action |
|----------|--------|
| `Super+Y` | Toggle float/tile |
| `Super+F` | Maximize |
| `Super+Shift+F` | Fullscreen |
| `Super+P` | Pin window |
| `Super+,` | Toggle window group |
| `Super+U` | Ungroup window |
| `Super+Alt+Arrows` | Resize window |
| `Ctrl+Alt+Tab` | Cycle group forward |

### Workspaces
| Shortcut | Action |
|----------|--------|
| `Super+1-0` | Switch to workspace 1-10 |
| `Super+Shift+1-0` | Send window to workspace |
| `Super+S` | Toggle scratchpad |
| `Super+M` | Spotify |
| `Super+Z` | Ferdium |
| `Super+B` | Calculator |
| `Super+Tab` | Previous workspace |

### Utilities
| Shortcut | Action |
|----------|--------|
| `Print` | Screenshot to clipboard |
| `Super+Print` | Screen snip |
| `Super+.` | Emoji picker |
| `Super+V` | Clipboard history |
| `Super+L` | Lock screen |
| `Super+Ctrl+Alt+W` | Change wallpaper |

### Gestures (Touchpad)
| Gesture | Action |
|---------|--------|
| 4 fingers horizontal | Switch workspace |
| 3 fingers up | Toggle special workspace |
| 3 fingers down | Toggle special workspace |

## Shell stability

The QuickShell shell hosts the bar, drawers, dashboard, and notifications
— nothing else. It runs under systemd (`quickshell-jarvos.service`) with
auto-restart so a crash recovers in seconds without dropping the Hyprland
session. The lock surface is **hyprlock**, not QuickShell — native C++,
no QML, no upstream Caelestia coupling, can't be killed by a Qt regression
or a mid-session `pacman -Syu`. A pre-commit lint refuses any QML that
puts `asynchronous: true` on a `Shape{}` (Qt's threaded shape renderer
races `ShapePath` and segfaults).

Full contract, including the four hard rules and the switchover steps, is
in [`docs/STABILITY.md`](docs/STABILITY.md).

## Architecture

```
JarvOS/
├── config/                        # Desktop dotfiles (stow-managed)
│   └── .config/
│       ├── hypr/
│       │   ├── hyprland.conf      # Main entry — sources all modules
│       │   ├── hyprland/
│       │   │   ├── animations.conf    # 9 bezier curves & animation timings
│       │   │   ├── colors.conf        # Theme colors (auto-generated from wallpaper)
│       │   │   ├── decoration.conf    # Blur, shadows, rounding, opacity
│       │   │   ├── env.conf           # Environment variables
│       │   │   ├── execs.conf         # Startup applications
│       │   │   ├── general.conf       # Gaps, borders, layout engine
│       │   │   ├── keybinds.conf      # All keybindings
│       │   │   ├── rules.conf         # Window, workspace & layer rules
│       │   │   ├── custom/*.conf      # Your overrides (not tracked by git)
│       │   │   └── scripts/           # Helper scripts
│       │   ├── hyprlock.conf      # Lock screen config
│       │   ├── hypridle.conf      # Idle management
│       │   └── shaders/           # GPU shader effects
│       └── quickshell/
│           ├── shell.qml          # Shell entry — enable/disable modules
│           ├── modules/           # 16 UI modules (92 reusable widgets)
│           └── services/          # 25 backend services
├── hypr-box/                      # AI control layer (submodule)
│   ├── hypr_box/
│   │   ├── backends/              # hyprctl, wtype, grim, wpctl wrappers
│   │   └── commands/              # 9 CLI command groups
│   └── pyproject.toml
├── install.sh                     # One-line installer
├── grub/                          # GRUB theme
├── sddm/                          # SDDM theme
└── wallpapers/                    # 26 curated wallpapers
```

### Customization

**Add keybinds without touching upstream:**
```bash
# ~/.config/hypr/hyprland/custom/keybinds.conf
bind = Super+Shift, G, exec, gimp
```

**Change monitors:**
```bash
# ~/.config/hypr/hyprland/monitors.conf
monitor = DP-1, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
```

**Toggle QuickShell modules:** Edit `~/.config/quickshell/shell.qml` — set any `enable*` property to `false`.

## Credits

- [chsoares/hypr-arch](https://github.com/chsoares/hypr-arch) — Original dotfiles foundation, installer, SDDM/GRUB theming, and desktop integration
- [END-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — QuickShell desktop shell, Material Design 3 widget system
- [Caelestia](https://github.com/caelestia-dots/caelestia) — Animation physics, gestures, window groups, dynamic gaps
- [Hyprland](https://hyprland.org/) — Wayland compositor
- [QuickShell](https://quickshell.outfoxxed.me/) — Qt/QML shell framework

## License

MIT
