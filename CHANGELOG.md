# Changelog

All notable changes to the JarvOS runtime. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
tags the `jarvos` package is built from.

## [Unreleased]

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
