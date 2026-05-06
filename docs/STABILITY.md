# Shell stability invariants

This shell crashed under threaded rendering for two reasons that compounded:
QML `Shape` racing its own `ShapePath` children, and a lock surface that
shared the main shell process so that any GPU stall in the bar took the
authentication overlay down with it. The four rules below are the contract
that keeps QuickShell up. Break any of them and you reintroduce the
intermittent segfault matrix that motivated this overhaul.

## The four hard rules

### 1. Never declare `asynchronous: true` on a `Shape{}`

`QtQuick.Shapes` instantiates each `ShapePath` on a worker thread when its
parent `Shape` is asynchronous. The renderer (`Shape.CurveRenderer`) reads
gadget properties from the GUI thread while the worker is still mutating
them — an unguarded data race that segfaults `libQt6Declarative.so.6` under
`QSG_RENDER_LOOP=threaded`. The `preferredRendererType: Shape.CurveRenderer`
line stays; `asynchronous: true` does not.

`asynchronous: true` is fine and expected on `Image{}`, `AnimatedImage{}`,
and `Loader{}` — those have proper internal synchronization. The lint gate
allow-lists them.

### 2. The lock surface runs in its own QuickShell process

`shell.qml` and `lock-shell.qml` are two independent QML entrypoints
launched as two systemd user units. The bar can crash, leak, or hang and
the lock overlay still authenticates. `Super+L` and hypridle both go
through `~/.config/hypr/hyprland/scripts/jarvos-lock.sh`, which calls the
lock IPC handler if the dedicated process is up and starts the unit
otherwise.

### 3. The shell runs under systemd, not `exec-once`

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

The lock unit is on-demand. Do not enable it at boot — it starts itself
the first time the lock script needs it.

### Verifying the install

```sh
config/.config/quickshell/scripts/lint-shape-async.sh \
    config/.config/quickshell/jarvos
systemd-analyze --user verify \
    ~/.config/systemd/user/quickshell-jarvos.service \
    ~/.config/systemd/user/quickshell-jarvos-lock.service
```

Both must exit zero.

### When the lock service refuses to start

`journalctl --user -u quickshell-jarvos-lock.service -n 100` first. The
common failure is a QML import error in `modules/lock/` — the same shell
runs in two processes, so a regression in the lock module breaks both
units, not just one. Run `qmllint config/.config/quickshell/jarvos/lock-shell.qml`
and walk the imports.

### After every upstream Caelestia merge

Before testing the merged tree:

```sh
config/.config/quickshell/scripts/lint-shape-async.sh
systemd-analyze --user verify \
    ~/.config/systemd/user/quickshell-jarvos.service \
    ~/.config/systemd/user/quickshell-jarvos-lock.service
config/.config/quickshell/scripts/stress/stress-run.sh patched 60
```

If the lint fails, upstream landed a `Shape{...asynchronous: true}` —
strip the property in the affected file and re-run. The stress harness is
a regression detector, not a race reproducer: a clean 60-second patched
run plus a clean lint is the contract. If the lint passes but the harness
unexpectedly crashes, treat that as a new defect class and capture a
fresh `coredumpctl gdb` backtrace before patching further.

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
