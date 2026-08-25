# Decision: workspace-scoped job contexts

**Date:** 2026-08-25
**Status:** decided, not yet specced — sequenced after the Caelestia removal
**Decided by:** chairman

## Decision

JarvOS grows an omarchy-style theming system, expanded in two directions: a
**job context** (bug bounty, development, CTF, DFIR and threat hunting) is the
unit, and it is bound to a **Hyprland workspace**, not a monitor.

A context is a **full working context**, not a palette. It owns:

- **Theme** — palette, wallpaper, bar accent.
- **Workspace** — which apps launch, how they are arranged, which scratchpads
  exist.
- **Environment** — working directory, env vars, tool defaults, case or
  engagement paths, and which vault collection is live.

**Binding:** `jarvos-context set <name>` applies to the workspace you are
currently on and persists there. Not a declared per-workspace mapping in
config — you can run two engagements on two workspaces, or move a job to
another screen.

## Why workspaces, not monitors

Apps cannot follow a monitor. A terminal does not know which screen it is on
and takes its colours from its own config; Hyprland's border colours are
global. Per-monitor theming could therefore only ever have covered shell chrome
and wallpaper, while costing a refactor of the 1,222 `Colours.*` references
that currently read a global singleton.

Workspaces map to jobs far better than monitors do, are already per-monitor in
Hyprland, and can theme the apps launched inside them.

## Two constraints the design must respect

**Environment applies only to new processes.** A context switch cannot inject
env vars or a working directory into already-running processes — the same class
of limit as apps not following monitors. Switching to DFIR on a workspace with
a shell already open leaves that shell in the old environment. The design must
either accept this and say so plainly in the UI, or launch context-aware
wrappers rather than mutating anything.

**Secrets scope is security surface, not a feature toggle.** "Which secrets are
live" touches `~/.secrets/.env.central` and the rules in `CLAUDE.md`: secrets
are referenced by variable name, never read into code, never logged raw. A
context that narrows or selects a secrets scope must not become a mechanism
that materialises values into a shell, an env file, or a log. **Invoke the
`vault-working` skill before designing this part**, and treat it as its own
decision — it is the one piece here that can fail unsafely rather than merely
badly.

## Overlaps to reconcile when specced

- Existing case tooling: `~/cases/`, `~/evidence/`, the ES indices, and the
  clawmem vault collections already encode "which engagement am I in".
  A context should drive those rather than duplicate them.
- Per-workspace state needs somewhere to persist. `jarvos-state` markers are
  per-user; this needs per-user *and* per-workspace.
- The theming layer replaces `caelestia scheme`, which is why the scheme port
  during the Caelestia removal is deliberately throwaway scaffolding.

## Sequencing

After the Caelestia removal lands. Both rewrite `services/Colours.qml`,
`services/Wallpapers.qml`, and the scheme CLI; doing theming first would build
against types scheduled for deletion.
