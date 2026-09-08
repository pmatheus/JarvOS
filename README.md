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
          │  Hyprland  +  Omarchy Shell  +  JarvOS  +  Arch        │
          └─────────────────────────────────────────────────────────────┘
```

<p align="center">
  <em>The AI-native operating system.<br/>
  A modern Arch Linux desktop where AI agents see, interact with, and control<br/>
  every application, built on Hyprland and the Omarchy QuickShell desktop.</em>
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

> Uses the [Omarchy shell](https://github.com/omacom/omarchy/tree/quattro/shell) with JarvOS branding, agent tools, existing Hyprland configuration and the Chinese stratagem Hyprlock screen. Caelestia is no longer a runtime dependency. See [desktop operation and rollback](docs/omarchy-shell.md).

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

### Full-system bootstrap (bare Arch → this exact box)

`install.sh` sets up the desktop on top of an existing system. `bootstrap.sh`
reproduces the **whole box** — packages, services, groups, and desktop — from a
clean Arch install:

```bash
git clone https://github.com/pmatheus/JarvOS.git ~/JarvOS && cd ~/JarvOS
./bootstrap.sh              # core desktop only (the beautiful OS)
./bootstrap.sh --apps       # + browsers / editors / media
./bootstrap.sh --security   # + security/RE toolkit (public tools)
./bootstrap.sh --full       # everything + optional services (docker/virt/...)
```

What it installs is declared, not magic — review/edit before running:

| File | Contents |
|------|----------|
| `dependencies.txt` | core repo packages |
| `system/packages/aur-core.txt` | AUR packages for the desktop |
| `system/packages/aur-apps.txt` | optional apps (`--apps`) |
| `system/packages/aur-security.txt` | security toolkit (`--security`) |
| `system/packages/*-full.txt` | complete snapshot of the reference box |
| `system/services/enable.txt` | services to enable (core vs optional) |

After bootstrap, edit `~/.config/hypr/hyprland/monitors.conf` for your displays.

**Keeping the snapshot current:** after changing the live box, run
`scripts/capture-system.sh` to refresh the package/service snapshots and report
dotfile drift, then review `git diff` and commit.

**Privacy / safety:** this repo ships **zero secrets** — no keys, tokens,
history, or private agent config. `scripts/secret-scan.sh` runs as a
`pre-commit` hook (`git config core.hooksPath .githooks`) and blocks any commit
containing secret-shaped strings. Per-host files (`monitors.conf`, matugen
`colors.conf`) are git-ignored and generated on install.

### Requirements
- Arch Linux or Arch-based distribution (EndeavourOS, CachyOS, etc.)
- UEFI system (for GRUB theme)
- Non-root user with sudo access

## Features

### Visual Design
- **JarvOS palette** with Omarchy desktop theme and wallpaper selection
- **Glassmorphism** blur on sidebar and overlays
- **Fluid animations** — 9 custom bezier curves for windows, workspaces, layers
- **Dynamic gap sizing** — single-window workspaces breathe with larger gaps
- **18px window rounding** with subtle shadows
- **85% inactive window opacity** with blur-through
- **6 GPU shaders** — CRT, chromatic aberration, solarized, invert, and more

### Active shell components
| Module | Description |
|--------|-------------|
| **Bar** | Per-monitor taskbar with workspaces, clock, media, battery, sys tray |
| **Panels** | Audio mixer, network, Bluetooth, monitors and power |
| **Launcher** | Search applications and JarvOS commands |
| **Notifications** | Omarchy popup notifications, history and actions |
| **OSD** | On-screen volume and brightness indicators |
| **Media Controls** | MPRIS player control overlay |
| **Weather** | Current weather widget |
| **Clock/Calendar** | Full-featured calendar and clock monitors |
| **Keybindings** | Active bindings in the terminal (Super+H) |
| **Session** | Power menu with lock, logout, suspend, shutdown |
| **Clipboard / emoji** | Separate searchable native pickers |
| **JarvOS extensions** | Identity, agent picker and optional module setup |

The previous QML shell remains in the repository as reference code. Its todo
sidebar, touch keyboard and background widgets are not active in this session.

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
| `Super` | JarvOS command menu |
| `Super+Space` | Application launcher |
| `Super+Return` | Terminal |
| `Super+E` | File manager |
| `Super+W` | Browser |
| `Super+Q` | Close window |

### Shell Panels
| Shortcut | Action |
|----------|--------|
| `Super+N` | Show notification history |
| `Super+H` | Read active keybindings |
| `Super+K` | JarvOS command menu |
| `Super+I` | Desktop settings menu |
| `Super+Shift+U` | JarvOS tools |
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

The Omarchy QuickShell process hosts the bar, panels, background and notifications.
It runs under systemd (`quickshell-jarvos.service`) with
auto-restart so a crash recovers in seconds without dropping the Hyprland
session. Hyprlock runs separately and remains locked across shell restarts.
A pre-commit lint refuses any QML that
puts `asynchronous: true` on a `Shape{}` (Qt's threaded shape renderer
races `ShapePath` and segfaults).

Current operation and rollback are documented in
[`docs/omarchy-shell.md`](docs/omarchy-shell.md). The earlier shell's stability
history is in [`docs/STABILITY.md`](docs/STABILITY.md).

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
│       ├── omarchy/               # Active layout, JarvOS plugins and theme
│       └── quickshell/            # Retired shell and retained helper scripts
├── share/jarvos/omarchy/          # Upstream revision and compatibility commands
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

**Restart the shell:** `systemctl --user restart quickshell-jarvos.service` (Super+Ctrl+Alt+R).

## Maintenance

```
jarvos-version              which JarvOS is this
jarvos-migrate --pending    what a new release wants to repair
jarvos-migrate              apply it
jarvos-state list           what the runtime has flagged
```

Migrations run once per machine per user and record themselves under
`~/.local/state/jarvos/migrations/`. Delete a marker to replay exactly that
one.

## Credits

- [omacom/omarchy](https://github.com/omacom/omarchy) — Active desktop shell, panels, menus and theme engine
- [chsoares/hypr-arch](https://github.com/chsoares/hypr-arch) — Original dotfiles foundation, installer, SDDM/GRUB theming, and desktop integration
- [END-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — QuickShell desktop shell, Material Design 3 widget system
- [Caelestia](https://github.com/caelestia-dots/caelestia) — Animation physics, gestures, window groups, dynamic gaps
- [Hyprland](https://hyprland.org/) — Wayland compositor
- [QuickShell](https://quickshell.outfoxxed.me/) — Qt/QML shell framework

## License

JarvOS is licensed under the GNU General Public License v3.0 only — see
[LICENSE](LICENSE).

The retired JarvOS shell (`config/.config/quickshell/jarvos/`) derives from
[Caelestia](https://github.com/caelestia-dots/caelestia), which is
GPL-3.0-only. That copyleft is why the whole repository is GPL-3.0-only.
