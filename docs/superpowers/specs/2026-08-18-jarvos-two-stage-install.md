# JarvOS v0.2.0 — two-stage install, binary repo, Bubble Tea TUI, first-run app

Date: 2026-08-18 · Status: approved by chairman · Supersedes the install flow in
`2026-08-17-jarvos-iso-design.md` (ISO build, cidata, archinstall usage stay).

## Why

v0.1.0 measured: the `core` profile makes the installer **compile** `quickshell-git`,
`caelestia-shell`, `caelestia-cli`, `libcava`, `qt6gtk2`, `adw-gtk-theme-git` and four
`-git` fonts inside the target. Observed: 40+ minutes and still going; with
`ferdium-bin` (now removed from core) it also built Electron from source. A distro
that claims "fastest to install" cannot compile C++/Qt on the user's machine.

## Decisions (chairman, 2026-08-18)

| Topic | Decision |
|---|---|
| Install shape | **Two stages.** Stage 1 = the minimum for the GUI to look right. Stage 2 = everything else, chosen by the user at first boot. |
| Speed target | Stage 1 ≤ 8 min wall clock in QEMU on this box (baseline: 40+ min). |
| Compilation | **Never on the user's machine.** All AUR packages are prebuilt here and served from a binary repo. |
| Binary repo | `[jarvos]`, published as GitHub Release assets on `pmatheus/jarvos-iso` (tag `repo-x86_64`), GPG-signed. |
| Installer UI | **Go + Bubble Tea** (Charm — same family as gum), cockpit layout, `d` toggles the live log, `s` opens an emergency root shell. Raw output never on screen by default. |
| First-run UI | **Native QML app in the JarvOS shell** ("JarvOS Setup"): module cards, installs in the background while the user already uses the desktop. |
| Module catalogue | Apps · AI layer · Security/CTF · Dev. |
| Release | v0.1.0 is held. The first public ISO is v0.2.0, with the TUI and the two-stage flow. |

## Architecture

### 1. `[jarvos]` binary repo
- `bin/jarvos-repo-build [pkg…]` (jarvos-iso): builds each AUR package in a clean
  chroot (`devtools`), signs it, runs `repo-add -s -v jarvos.db.tar.zst`, writes into
  `repo/x86_64/`.
- `bin/jarvos-repo-publish`: uploads `repo/x86_64/*` to the `repo-x86_64` release
  (`gh release upload --clobber`). The build machine publishes; no hosted CI.
- Signing key: dedicated GPG key "JarvOS Repo"; the public key ships in the ISO at
  `/usr/share/jarvos-iso/jarvos.gpg` and is installed into the target keyring
  (`pacman-key --add` + `--lsign-key`) before the first `[jarvos]` install.
- Client config (ISO and target `/etc/pacman.conf`):
  `[jarvos]` / `SigLevel = Required DatabaseOptional` /
  `Server = https://github.com/pmatheus/jarvos-iso/releases/download/repo-x86_64`
- Package set v1 = every AUR package stage 1 needs. Module packages follow.

### 2. Stage 1 — the ISO install
- `system/packages/stage1.txt` (JarvOS repo) is the complete list: base, kernel,
  NetworkManager, SDDM, Hyprland stack, quickshell + the JarvOS shell, kitty, fish,
  fonts, matugen/colour tooling, hypr-box's runtime (uv), grub.
- `chroot-setup.sh` installs it with **pacman only** — no yay, no makepkg. It still
  deploys the dotfiles, enables services, and writes `/etc/jarvos-release`.
- Everything else moves out of the installer.

### 3. Installer TUI (Go, Bubble Tea)
- Source in `tui/` (jarvos-iso), built by `bin/jarvos-iso-make` into the airootfs as
  `/usr/local/bin/jarvos-installer-ui` (static, `CGO_ENABLED=0`).
- `jarvos-install` writes `/run/jarvos-install/state.json` (phase list, current phase,
  step N/M, short message, ETA input) and keeps the raw log in
  `/var/log/jarvos-install.log`. The TUI renders state, tails the log on demand.
- Layout: cockpit (header with target/profile, phase list, discreet telemetry pane,
  global progress bar, key hints). Console-safe: 16-colour palette redefined at boot,
  box drawing only, no emoji.
- Keys: `d` live log full screen (scroll, `d`/Esc back), `s` root shell on tty3,
  `q` only after the install ends.
- Failure: red banner, log path, drops to the log view rather than rebooting.

### 4. Stage 2 — first-run "JarvOS Setup" (QML)
- Ships with the shell (`config/.config/quickshell/jarvos/modules/setup/`), launched on
  first login when `~/.local/state/jarvos/first-run-done` is absent.
- Cards from `system/modules/*.module` (name, description, icon, packages, post-install
  hook). Selecting modules queues them; a backend script installs in the background
  (yay for anything still not in `[jarvos]`), progress shown in the bar; the desktop
  stays usable throughout.
- The user can reopen it later (`jarvos-setup`), and skipping is a first-class choice.

## Verification

1. `bin/jarvos-repo-build` produces a signed repo; a clean container/VM can
   `pacman -Sy quickshell-git` from `[jarvos]` with signature checking on.
2. Timed QEMU run: stage 1 from boot to SDDM ≤ 8 min, recorded in the report.
3. TUI: no raw package output on tty1 during a full install; `d` shows the log; `s`
   gives a shell; failure path shows the banner. Verified in a real run + Go unit tests
   for the state parser.
4. First boot: Setup app appears, installing "AI layer" adds hypr-box and reports done
   without blocking the desktop.
5. ISO < 2 GiB, published as v0.2.0 with the site updated.

## Out of scope

Offline embedded mirror, Secure Boot, aarch64, dual-boot with Windows.
