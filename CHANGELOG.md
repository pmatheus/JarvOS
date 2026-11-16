# Changelog

All notable changes to the JarvOS runtime. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
tags the `jarvos` package is built from.

## [Unreleased]

## [0.4.0] — 2026-11-16

The release where the box looks after itself: a daily update that repairs,
rolls back and reports; a shell that comes back when it dies; and an install
that reproduces the running machine.

### Added

- `jarvos-update` — the single blessed way to bring a machine current, with
  a transcript, a rollback snapshot, and mutual exclusion. Git, keyring,
  system-package, AUR, orphan, log-analysis and restart steps.
- A self-repairing daily update (`jarvos-update.timer` → `jarvos-update-auto`):
  per-step repair rules, an AI resolver as a second line, and a live rollback
  that restores only system paths when the health gate fails. The outcome is
  kept in `reports/last-update.json`.
- Updates reach running code: `jarvos-update-stale` finds processes still
  mapping replaced libraries and `jarvos-update-restart-stale` restarts the
  safe ones; a kernel upgrade no longer strands the running kernel's modules.
- `jarvos-update-pacnew` — lists `.pacnew`/`.pacsave` files after every update,
  counts them in the report, and the nightly run notifies with `sudo pacdiff`.
  It never merges.
- `jarvos-shell-failed` — when the shell has crashed past its start limit,
  keeps its log in `reports/shell-failed.log` and notifies with the restart and
  diagnose commands.
- `jarvos-refresh-config`, `jarvos-hook` (post-update, post-boot,
  pre-refresh-pacman, theme-set), `jarvos-restart-shell` and marker-driven
  restart dispatch.
- The agent layer (`jarvos-agent*`, Super+A, usage tracking) and the DFIR field
  tooling (`jarvos-case`, triage, IOC, diagnose).
- `jarvos-vpn` — one client for every VPN vendor, with per-profile tunnels,
  keyring passwords and 2FA in the shell.
- First-run Setup panel and module catalogue; `jarvos-sync` machine continuity.
- Rescue tooling (`jarvos-rescue`, `jarvos-gpu-ok`, `jarvos-hypr-safe`) and
  `jarvos-monitor-layout`, now versioned in `bin/`.
- A `PKGBUILD`, so the runtime tooling reaches `$PATH` for the first time.
- A LICENSE: GPL-3.0-only, inherited from the Caelestia fork the shell
  derives from.

### Changed

- The shell runs on native JarvOS services; the Caelestia runtime is gone.
- The Hyprland configuration is Lua.
- The installers link every JarvOS command onto `$PATH` (they linked two, so
  a fresh install's timer and monitor service ran commands nobody installed),
  and link the shell into the checkout instead of copying it, so an update of
  the checkout reaches the running desktop.
- The shell restarts by itself after a crash (`Restart=on-failure`,
  `RestartMode=direct`).
- A failing migration keeps its output in `reports/migration-<name>.log`,
  notifies, and prints the diagnose command.
- Logging out exits Hyprland instead of `loginctl terminate-user`, which took
  SDDM down with the session.
- The pre-commit secret gate installs itself from `bootstrap.sh` instead of
  waiting to be opted into.

### Fixed

- `jarvos-update` died before doing anything when no graphical session was
  active (the nightly timer, an SSH login): polkit asked for a password to
  inhibit sleep. It now goes on uninhibited.
- `jarvos-update.service` pointed its documentation at a path that only exists
  when the package is installed.

## [0.3.0] — 2026-08-25

The first release boundary. Before this tag there were no releases to
migrate between, so this is where the maintenance layer starts counting.

### Added

- `jarvos-version` — reports the running version. The package database is
  the oracle; a git checkout reports `dev (<hash>)`.
- `jarvos-migrate` — applies the one-time repair scripts a release ships,
  once per migration per user, in commit-timestamp order. `--adopt`, run at
  login, marks everything shipped for a user who has never migrated, so an
  account created later on an up-to-date box does not replay history.
- `jarvos-state` — runtime markers under `$XDG_STATE_HOME/jarvos`, where the
  filename is the dispatch.
- `jarvos-pkg-present`, `jarvos-pkg-missing`, `jarvos-pkg-add`,
  `jarvos-pkg-drop` — the vocabulary migrations are written in. `add` and
  `drop` re-verify with `pacman -Q`, because pacman can exit 0 having done
  nothing.
- `tests/run-all.sh` — every suite plus `shellcheck` over the runtime scripts.

### Changed

- `bootstrap.sh` and `install.sh` mark every shipped migration applied on a
  fresh install, so a first boot migrates nothing.

### Fixed

- Notification popups no longer render their clear-all button on top of the
  topmost card's text; the button is a notification-centre action and now
  lives only there.
- The sidebar styles critical notifications correctly — it was comparing an
  enum-backed `urgency` against the string `"critical"`, which never matched.
- The network popout's settings row opens the in-shell network pane instead
  of spawning `nm-connection-editor`.
