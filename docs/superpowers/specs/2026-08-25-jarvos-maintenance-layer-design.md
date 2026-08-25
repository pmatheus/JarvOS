# JarvOS Maintenance Layer — Design

**Date:** 2026-08-25
**Status:** Approved for planning
**Scope:** The layer that keeps an *already installed* JarvOS machine current and repairable.

---

## 1. Context

`~/jarvos-iso` already solves getting JarvOS onto a machine: an archiso profile, ~20
PKGBUILDs feeding a `[jarvos]` binary repo, a Go/Bubble-Tea installer TUI, and a built
`jarvos-0.2.0-x86_64.iso`. That half works.

Nothing exists for the half that comes after. `~/JarvOS` — the runtime — has:

- no version file, no git tags, no changelog
- no migrations directory and no migration runner
- no `jarvos-update` or any refresh command
- a dotfile deployment (`cp -rf`, `bootstrap.sh:149` and `install.sh:240`) that clobbers
  user edits with no backup, no merge, and no diff
- no path for a new release to add or remove a package on an existing install
- no runtime tooling on `$PATH` (`jarvos-setup`, `jarvos-sync`, `jarvos-module-install`
  are never installed anywhere; `jarvos-module-install` searches
  `/usr/share/jarvos/modules`, a path nothing populates)

An installed machine cannot answer "which JarvOS am I running?". The only `0.2.0` lives
in the ISO's airootfs and is never read again after install.

The decision taken 2026-08-25: JarvOS targets **public distribution**. Configs are ours,
overwritten on update, with a documented override layer; migrations must survive machines
we have never seen; real versioning and a changelog.

### The failure this exists to prevent

On 2026-08-25, `qt6-base` moved 6.11.1 → 6.11.2 (installed 2026-08-21). `quickshell-git`
links Qt private API, which carries no ABI guarantee across point releases. The running
shell survived only because its process predated the upgrade and still had the old
libraries mapped. Any fresh `qs` invocation died:

```
qs: symbol lookup error: qs: undefined symbol:
_ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6_PRIVATE_API
```

A logout would have left no desktop and no shell to repair it from. On our own machine
that is an afternoon. Shipped to strangers, it is an unrecoverable brick delivered by a
routine `pacman -Syu`.

---

## 2. Non-goals

- **Not a rollback engine.** Recovery is rebooting into a snapper snapshot. pacman is
  already transactional per transaction; a bespoke rollback would be untestable.
- **Not package reconciliation.** The manifest stays a seed list. Package changes on
  existing installs happen through migrations. (This is omarchy's weakest point and we
  inherit the weakness knowingly — see §10.)
- **Not the v4 package-backed architecture yet.** That needs a signed pacman repo,
  multiple mirrors, a keyring package and `/etc/skel` seeding. We adopt the git-checkout
  model first, which delivers migrations, hooks, refresh-config and state markers with no
  hosted infrastructure.
- **Not AI integration.** Separate workstream, specced separately.

---

## 3. Architecture: the ownership split

The load-bearing decision. Today every one of our ~475 shipped config files (365 of them
quickshell QML) lives in `~/.config` and is simultaneously ours and the user's. That is
what makes every update a merge problem.

**The QML is not config. It is the program.** It only lives in `~/.config` because that is
where quickshell looks by default. Quickshell searches every XDG config directory —
confirmed from `qs --help`:

> Quickshell detects configurations as named directories under each XDG config directory
> as `<xdg dir>/quickshell/<config name>/shell.qml`
>
> `/etc/xdg/quickshell/myconfig/shell.qml` can be run with `qs -c myconfig`

omarchy ships their entire Quickshell desktop this way (`docs/file-layout.md:80`:
`shell/** ──► /usr/share/omarchy/shell/`).

So:

| Tree | Owner | Update behaviour |
|---|---|---|
| `/etc/xdg/quickshell/jarvos/**` | JarvOS | Overwritten wholesale, every update |
| `/usr/share/jarvos/**` (defaults, migrations, modules) | JarvOS | Overwritten wholesale |
| `~/.config/caelestia/shell.json` | User | Never touched by an update |
| `~/.config/hypr/custom/*.conf`, `monitors.conf` | User | Never touched |
| `~/.local/state/jarvos/**` | Runtime | Markers, generated state |

`shell.json` is already the user's real surface — bar layout comes from
`.bar.entries` there, not from `BarConfig.qml`. We are not inventing a layering
mechanism; we are moving the boundary to where it already is.

**Consequence:** this deletes the "two copies of config, edit both" rule from
`CLAUDE.md`. There is one tree.

### Hyprland

The one genuinely unsolved piece. Hyprland's `source` can add but cannot *subtract* — a
user cannot unbind one of our keybinds from an override file. omarchy solved this by
moving to Lua (`require` + `unbind`), which is a real commitment: they ship
`bootstrap.lua`, `helpers.lua`, `require_all.lua`, `require_optional.lua` to support it.

**This needs a spike before we commit.** Options, to be evaluated with evidence:

1. Adopt Hyprland's Lua config path, mirroring omarchy.
2. Ship defaults as `source`d fragments plus a documented `unbind = ` escape in
   `custom/*.conf` (works, but users must know the binding to unbind it).
3. Generate the final `hyprland.conf` from defaults + user overrides at update time.

Everything else in this spec is independent of that choice.

---

## 4. Versioning

**The package database is the oracle.** `pacman -Q jarvos` reports the version; there is
no file to forget to bump.

```
jarvos-version:
  if $JARVOS_PATH is not the packaged path  → "dev (<short-hash>)"
  else                                       → pacman -Q jarvos | awk '{print $2}'
```

Releases are git tags `vN.N.N` with a `CHANGELOG.md` in the runtime repo. We currently
have zero tags, so there are no release boundaries to migrate between — cutting `v0.3.0`
is a prerequisite for the first migration.

---

## 5. Migrations

A directory of one-time repair scripts for machines that already exist.

**Naming:** `migrations/<unix-timestamp>.sh`, where the timestamp is
`git log -1 --format=%cd --date=unix` — the **commit date of HEAD**, not the wall clock.
Ordering is then derived from repo history, so branches cannot produce out-of-order names
and a rebase cannot scramble sequence.

**Permissions:** mode `0644`, **no shebang**. The runner supplies strictness via
`bash -euo pipefail "$file"`. A migration is data to be interpreted, never a program, and
cannot be invoked accidentally by a stray `./`.

**Applied state:** one empty marker file per migration, **per user**:
`~/.local/state/jarvos/migrations/<filename>`. Per-user because every user on a box must
get a chance at every migration; the cost is that migrations doing machine-wide work must
no-op when it is already done.

**The runner** (`jarvos-migrate`, ~40 lines):

- glob `migrations/*.sh` — lexicographic order is chronological order, so no sort, no
  index, no manifest
- skip any with an existing marker
- run under `bash -euo pipefail`; **write the marker only on success**, so a failure
  retries next run rather than leaving half-applied bookkeeping
- fail hard on error. No skip prompt. A "skipped" migration is a permanently divergent
  machine nobody can reason about again.
- wait on `/var/lib/pacman/db.lck` before starting, bounded at 15 minutes, then **exit 0**
   — a busy pacman is a deferral, not an error
- `--pending` lists pending migrations and exits 0 when there are some, non-zero when
  there are none, so watchers can write `if jarvos-migrate --pending; then notify; fi`

**House style:** first line is `echo` of the intent (it is the user-visible progress
output), then a comment explaining *why*, then a guarded action. The guard is the
idempotency:

```bash
echo "Install MPRIS support for mpv"

jarvos-pkg-add mpv-mpris
```

### The five lines that matter most

At install time, **pre-mark every shipped migration as already applied**:

```bash
mkdir -p ~/.local/state/jarvos/migrations
for file in "$JARVOS_PATH"/migrations/*.sh; do
  touch ~/.local/state/jarvos/migrations/"$(basename "$file")"
done
```

Without this, migration N must be safe to run on a machine that never had state N-1. That
contract is impossible to hold across hundreds of migrations and the system collapses
under its own compatibility burden after roughly fifty. This must land **before the first
migration is ever written**.

### Pruning

Migrations are not kept forever. A major version is the amnesty point: cut the backlog and
replace it with one purpose-built upgrader. omarchy dropped ~240 of 330 at their 3→4
boundary.

---

## 6. `jarvos-update`

The single blessed entry point. Orchestration only; every step is a separate command.

```
jarvos-update [-y]
  ├─ re-exec under script(1) → /tmp/jarvos-update.log     (transcript, keeps progress bars)
  ├─ re-exec under flock                                   (no overlapping updates)
  ├─ free-space gate (10 GiB)                              (before the confirm prompt)
  ├─ confirm (unless -y)
  ├─ prune pacman cache                                    (BEFORE the snapshot)
  ├─ snapper snapshot                                      (the rollback point)
  ├─ inhibit sleep
  ├─ jarvos-update-git        git pull --autostash
  ├─ jarvos-update-keyring
  ├─ jarvos-update-system-pkgs
  ├─ jarvos-migrate                                        (AFTER packages)
  ├─ jarvos-hook post-update
  ├─ jarvos-update-aur-pkgs                                (third-party last)
  ├─ jarvos-update-orphan-pkgs
  ├─ jarvos-update-analyze-logs
  └─ jarvos-update-restart
```

Ordering rationale, each of which is a real constraint:

- **Prune before snapshot** — the cache sits on the snapshotted subvolume, so pruning
  after frees nothing until that snapshot ages out.
- **git pull before packages** — a merge conflict must abort before any system mutation.
  Use `--autostash`, then `diff --check || reset --merge` so a conflicted tree is
  abandoned rather than shipped.
- **Keyring before packages** — a stale keyring fails the main transaction
  unrecoverably.
- **Migrations after packages** — migrations ship with the packages installed above and
  are written against them. An upgrade that stopped must take the update with it rather
  than migrating against what is still on disk.
- **AUR last** — a broken AUR build must not take down the system update.

**Two self-re-exec preludes.** `script -qefc` gives a full transcript while keeping a PTY
so pacman's progress bars still render (a plain `| tee` kills them); an env var is the
recursion guard. `flock` on an FD carried through the environment, verified via
`readlink -f /proc/$$/fd/$FD`, means no PID files.

**Failure handling.** `set -e` plus an `ERR` trap that prints where the transcript is. No
automatic recovery. Recovery is out-of-band: reboot into the snapshot, or re-run — every
step is either `--needed`-guarded or marker-guarded, so retry is a real remedy.

**Hyprland must be muted across the pull.** Hyprland watches its config files and will
spew errors as they change underneath it. Suppress, pull, then one explicit `hyprctl
reload`.

**`-y` is a promise, not a force.** Unattended mode makes prompting steps report and skip,
never block. Orphan removal never removes non-interactively.

---

## 7. `jarvos-refresh-config`

The single primitive for pulling a shipped default forward over a user file. Backup,
overwrite, diff — and **delete the backup if nothing actually changed**, so the user sees
noise only when they genuinely lost something.

```
backup  = <user file>.bak.<timestamp>
cp user → backup ; cp default → user
cmp -s user backup  → identical? rm backup, print nothing
                    → differs?   print the path, the backup name, and the diff
```

**Never runs automatically as part of an update.** It is user-invoked, or called
explicitly by a migration when a shipped stub genuinely must change.

Guard the argument against `..` — omarchy documents this exact hole
(`AGENTS.md:131-133`) and has not fixed it. Reject any path that does not normalise to a
child of `~/.config`.

`jarvos-sync restore` already has timestamped-backup logic
(`~/.jarvos-sync-backup/<ts>/`) that `bootstrap.sh` does not reuse. Share one
implementation.

---

## 8. Escape hatches

**Hooks** — `~/.config/jarvos/hooks/<event>.d/*`, run-parts style. Skip `*.sample`; a
failing hook reports and never aborts. Each `.d/` ships a `.sample` the user renames to
activate, which makes the mechanism self-documenting. Initial events: `post-update`,
`post-boot`, `pre-refresh-pacman`, `theme-set`.

**State markers** — `jarvos-state set|clear <name>` writes/removes
`~/.local/state/jarvos/<name>`. The filename *is* the dispatch: a marker
`restart-<service>-required` causes `jarvos-update-restart` to run
`jarvos-restart-<service>`. Any migration can request a service restart by touching a
file, with no edit to the update pipeline.

**Package primitives** — `jarvos-pkg-add|drop|present|missing`. `add` must re-verify with
`pacman -Q` after installing, because pacman sometimes exits 0 without installing. These
are the vocabulary migrations are written in, which is what lets a migration read as
prose.

---

## 9. Packaging and distribution of the runtime

Currently nothing installs the runtime tooling. Required:

- a `PKGBUILD` for `jarvos` (runtime: `bin/`, `migrations/`, `system/modules/`, the
  shell tree) built into the existing `[jarvos]` repo
- commands land on `/usr/bin`; modules land on `/usr/share/jarvos/modules`, the path
  `jarvos-module-install` already searches
- a `LICENSE` in the runtime repo (absent; `jarvos-iso` has one)
- the pre-commit secret gate auto-configured rather than opt-in — a fresh clone currently
  ships with no gate at all

### Pinning Arch behind upstream

The single highest-leverage decision available, and the direct answer to §1's failure.
Our stable channel's mirror runs **one month behind** upstream Arch, so ABI breaks like
Qt 6.11.1 → 6.11.2 surface on `edge` first, on our machines, not on a user's.

Channels: `stable` / `edge` / `dev`, each a `pacman.conf` + `mirrorlist` pair swapped
wholesale by `jarvos-channel-set` (never edited in place), with a
`pre-refresh-pacman` hook firing between the swap and the upgrade so a user can
re-inject custom repos. Use `-Syyuu` — moving stable-ward is a downgrade.

This is the one item in this spec that requires infrastructure we do not yet run.

---

## 10. Known weaknesses accepted

- **No package reconciliation.** Adding a package to the manifest reaches only new
  installs; a migration is *also* required. Forgetting one silently produces two classes
  of machine. Mitigation: a CI check that a manifest diff in a release is accompanied by a
  migration.
- **Idempotency is convention, unenforced.** Nothing tests it.
- **`.pacnew`/`.pacsave` unhandled.** `system/etc/` is an empty directory today. Deferred,
  but tracked — omarchy has the same gap open.
- **Migration backlog grows monotonically** between major versions.

---

## 11. Verification

The layer is done when all of the following are observably true:

1. `jarvos-version` on a packaged install prints the version from `pacman -Q jarvos`; on a
   git checkout prints `dev (<hash>)`.
2. A fresh install has **every** shipped migration pre-marked, and `jarvos-migrate` on
   first boot runs zero migrations. Verified in a clean VM, not by inspection.
3. A migration that exits non-zero leaves **no** marker, aborts the run, and re-runs on the
   next invocation. Verified with a deliberately failing fixture.
4. A migration is replayable: `rm ~/.local/state/jarvos/migrations/<f> && jarvos-migrate`
   re-runs exactly that one.
5. Two concurrent `jarvos-update` invocations: the second blocks or exits, never
   interleaves. Verified by racing them.
6. `jarvos-update` interrupted mid-run (SIGKILL after the package step) resumes correctly
   on re-run, with already-applied migrations not repeated.
7. `jarvos-refresh-config` on an **unmodified** user file prints nothing and leaves no
   `.bak`. On a modified file it prints the diff and leaves exactly one `.bak`.
8. `jarvos-refresh-config ../../etc/passwd` is rejected.
9. The shell loads from `/etc/xdg/quickshell/jarvos/` via `qs -c jarvos` with `~/.config`
   containing no QML at all. Verified in a clean VM.
10. `shell.json` customisations (bar entries) survive a full `jarvos-update`, byte-identical.
11. A package added to the manifest plus its migration lands on an existing install after
    one `jarvos-update`.
12. `jarvos-update` on a machine with no network fails cleanly with a readable message and
    leaves the system usable.
13. `shellcheck` passes on every new script.

Items 2, 9 and 10 require a VM. `~/jarvos-iso` already has QEMU test tooling
(`bin/jarvos-iso-test`) to build on.

---

## 12. Sequenced delivery

1. `jarvos-migrate` + install-time pre-marking + `jarvos-state` + `jarvos-pkg-*`
   (~150 lines total). Ship before writing a single migration.
2. Cut `v0.3.0` — the first release boundary. Add `CHANGELOG.md`.
3. `jarvos-refresh-config`, replacing `cp -rf` in both installers.
4. `jarvos-update` + `jarvos-hook`.
5. `PKGBUILD` for the runtime; tooling onto `$PATH`; LICENSE; secret gate auto-configured.
6. Shell relocation to `/etc/xdg/quickshell/jarvos/`.
7. Hyprland override spike, then the chosen layering approach.
8. Channels and the one-month-behind mirror.

Steps 1-5 need no new infrastructure. Step 8 does.
