# Shell stability invariants

The JarvOS shell crashed under threaded rendering when a vendored Caelestia
`Shape{}` raced its own `ShapePath` worker, and the same QuickShell process
held the WlSessionLock — so a GPU stall in the bar took the authentication
overlay down with it and bricked the session. The four rules below are the
contract that keeps the bar up and the machine recoverable. Break any of
them and you reintroduce the intermittent segfault matrix that motivated
this overhaul.

## The four hard rules

### 1. Never declare `asynchronous: true` on a `Shape{}`

`QtQuick.Shapes` queues a `QQuickShapeCurveRunnable` to a worker thread when
the parent `Shape` is asynchronous. The runnable emits `done()` back to a
Shape whose `QObjectPrivate::ConnectionData` is being torn down concurrently
— `cleanOrphanedConnections` then dereferences a freed pointer and
SIGSEGVs. The `preferredRendererType: Shape.CurveRenderer` line stays;
`asynchronous: true` does not.

`asynchronous: true` is fine and expected on `Image{}`, `AnimatedImage{}`,
and `Loader{}` — those have proper internal synchronization. The lint gate
allow-lists them.

### 2. The lock surface is hyprlock, not QuickShell

QML hot-reload, Caelestia upstream churn, and `pacman -Syu --noconfirm`
make QuickShell a poor host for an authentication overlay. The lockscreen
runs in `hyprlock` — native C++, no QML, no upstream-fork risk. `Super+L`
calls `hyprlock` directly; hypridle's `lock_cmd` is `pidof hyprlock ||
hyprlock`; `IdleMonitors` in the JarvOS shell calls hyprlock via
`Quickshell.execDetached`. The shell never instantiates `WlSessionLock` and
never imports `modules/lock`. The hyprlock config + helpers live under
`config/.config/hypr/hyprlock.conf` and `config/.config/hypr/hyprlock/`.

### 3. The JarvOS shell runs under systemd, not `exec-once`

`exec-once` orphans the shell on crash. `quickshell-jarvos.service`
restarts on failure with a 5-burst / 30-second rate limit, surfaces logs to
the journal, and lets you switch shells without killing Hyprland. Hyprland
boots the unit on session start; replacing the unit at runtime is just a
`systemctl --user restart`.

### 4. The pre-commit hook is part of the contract

`config/.config/quickshell/scripts/lint-shape-async.sh` is wired to
`.git/hooks/pre-commit` and re-run from `install.sh`. Any commit that
reintroduces rule 1 fails locally. Any installer run on a corrupt tree
refuses to deploy.

## Operational notes

### Switching to the systemd-managed shell

The exec-once line in `execs.conf` is already replaced. To finish the
switchover without a logout:

```sh
pkill -f 'qs -p .*jarvos/shell.qml' || true
systemctl --user enable --now quickshell-jarvos.service
```

### Verifying the install

```sh
config/.config/quickshell/scripts/lint-shape-async.sh \
    config/.config/quickshell/jarvos
systemd-analyze --user verify \
    ~/.config/systemd/user/quickshell-jarvos.service
hyprlock --version  # must be installed
```

All three must exit zero.

### After every upstream Caelestia merge

Before testing the merged tree:

```sh
config/.config/quickshell/scripts/lint-shape-async.sh
systemd-analyze --user verify ~/.config/systemd/user/quickshell-jarvos.service
DURATION_SEC=60 config/.config/quickshell/scripts/stress/stress-run.sh patched
```

If the lint fails, upstream landed a `Shape{...asynchronous: true}` —
strip the property in the affected file and re-run. The stress harness is
a regression detector, not a race reproducer: a clean 60-second patched
run plus a clean lint is the contract. If the lint passes but the harness
unexpectedly crashes, treat that as a new defect class and capture a
fresh `coredumpctl gdb` backtrace before patching further.

If the merge re-imports `modules/lock` or re-instantiates `Lock { ... }`
from `shell.qml`, REJECT it — rule 2 is non-negotiable. The QuickShell
shell handles bar/drawers/dashboard only.

### When hyprlock dies and Hyprland refuses to unlock

If hyprlock crashes (or you killed it during testing) and Hyprland's
"lockscreen app died" wall is up:

```sh
hyprctl keyword misc:allow_session_lock_restore 1
hyprctl dispatch exec hyprlock
```

Then type your password.

### Stress harness limits

The unpatched leg of `stress-run.sh` cannot reliably reproduce the
production `QQuickShapeCurveRunnable` SIGSEGV in 5 minutes — the synthetic
churn pattern doesn't recreate the lock-surface tear-down window where the
race first hit. Treat the harness as a one-sided guardrail: clean
patched-mode runs are evidence of stability; clean unpatched-mode runs are
evidence of nothing. The negative-side proof is the lint plus rule 1.

### Cross-references

- `~/.claude/projects/-home-user/memory/jarvos-quickshape-async-race.md` —
  the empirical write-up of the Shape async race, including stack traces.
- `~/.claude/projects/-home-user/memory/jarvos-upstream-sync.md` — upstream
  resync plan and the list of bitrot items this overhaul fixes.
