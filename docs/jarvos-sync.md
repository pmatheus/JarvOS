# `jarvos-sync` — machine continuity

Changing machines should be a non-event. JarvOS ships the desktop; `jarvos-sync`
ships **the delta** — the packages you added, the dotfiles you changed, the units
you enabled, and a manifest *naming* the secrets you must bring yourself.

    jarvos-sync init --repo my-jarvos-profile   # on the old box: seed a private repo
    jarvos-sync push                            # whenever the machine changes
    jarvos-sync status                          # what drifted since the last push
    jarvos-sync restore <repo-url>              # on the new box: become that machine

Script: `scripts/jarvos-sync`. Manifests: `system/continuity/`.
Tests: `tests/jarvos-sync-*.test.sh` (48 cases, no network, no root).

## The idea

| | Owned by | Lives in |
|---|---|---|
| The desktop, its dotfiles, the module catalogue | the distro | the public JarvOS repo |
| Extra packages, changed dotfiles, enabled units, pointers to secrets | you | **your** private repo |

Nothing the distro already ships is duplicated into your repo. `jarvos-sync`
compares against the JarvOS baseline and keeps only what differs, so the profile
stays small, readable, and reviewable.

## What the baseline is

* **Packages** — `system/packages/stage1.txt` plus every `[packages]` block in
  `system/modules/*.module`. That is exactly "a full install with every module
  ticked". The retired v0.1 tier files (`aur-core/apps/security.txt`) are used
  **only** when `stage1.txt` is absent: counting them alongside stage 1 would
  mark packages the distro no longer ships as already-provided, and your profile
  would quietly lose them.
* **Dotfiles** — `config/<path>` in the JarvOS tree maps to `$HOME/<path>`, and
  `wallpapers/` maps to `~/Pictures/Wallpapers/`. A file byte-identical to the
  shipped one is not captured.
* **Units** — `system/services/enable.txt`, split by scope.
* **uv tools** — what a module's `[post]` section *installs*. `hypr-box`, the AI
  layer this distro is named for, is a uv tool, so they have to travel. Neither
  shape in the catalogue names the tool in the install command itself:
  `security.module` loops over a list (`for t in a b …; do uv tool install "$t"`)
  and `ai.module` installs a local checkout by path (`src=…/hypr-box; uv tool
  install "$src"`). So the argument is traced back to whatever set the variable,
  and a path down to its last component. Two things are deliberately *not*
  baseline: a name under `[packages]`, which is a pacman package — the uv tool
  that happens to share its name is a different artefact — and a name a `[post]`
  merely mentions, like the `docker` in `usermod -aG docker,libvirt`. Reading
  either as "the catalogue provides it" would drop the user's tool without a
  word, which is the failure this capture exists to prevent.

Point the tool at a different tree with `JARVOS_ROOT`. Without it, it looks at
`/usr/share/jarvos`, then `~/JarvOS`, then the checkout it is running from.

## What is captured

`system/continuity/dotfiles.allow` is an **explicit map**, never a guess. It
covers the desktop config the distro ships (so only your edits travel), the
desktop state it does not ship (`nvim`, `btop`, `gtk-3.0`, `~/.local/bin`,
`~/Pictures/Wallpapers`, user systemd units), your git/editor identity, and the
agentic layer — `~/.claude` content plus the sibling `~/.codex`, `~/.gemini`,
`~/.config/opencode` harnesses. That last part is the point of the whole tool:
clone your `.claude` and fly.

Add your own entries in `system/continuity/dotfiles.allow.local` (untracked).

Beyond that map the profile carries what a package manager knows rather than
what a file holds: the explicit pacman packages and their AUR subset, the units
you enabled, a `dconf` dump, and your **uv tools** — the Python CLIs installed
with `uv tool install`. Those live under `~/.local/share/uv/tools`, which is on
no allow-listed path, so nothing else would carry them: before this, every one
of them was lost on a rebuild. Names travel, versions do not. A rebuild should
get the current release of each tool, and recording versions would turn every
routine upgrade into drift that `status` reports and `push` commits.

## What is never captured

Four independent mechanisms, in this order — a file must survive all four:

1. **Not in the allow-list** → never even looked at. `~/Documents`, `~/.mozilla`,
   your projects: out of scope by construction.
2. **`system/continuity/dotfiles.deny`** → glob patterns over the home-relative
   path, matched *before the file is opened*. Covers `~/.secrets`, every `.env*`,
   keys and certificates, `~/.ssh`, `~/.gnupg`, `~/.aws`, shell and agent
   history, Claude Code transcripts and caches, plugin checkouts (re-fetched from
   their manifests instead), and host-specific state: `monitors.conf`,
   `colors.conf`, `scheme/`, `.current_system.json`, `~/.local/state`, machine-id.
   `*` crosses `/` in these patterns.
3. **`system/continuity/secret-patterns.txt`** → the content gate. Any file
   carrying a secret-shaped string is refused *whatever it is called*, and named
   in `secrets.manifest`. This is why the denylist does not need a blunt
   `*token*` rule that would also swallow `hooks/redact-secret-output.py`.
4. **The pre-commit gate** → the whole profile tree is re-scanned before every
   commit, so anything dropped in by hand is caught too.

Also skipped, and listed in the profile's `notes.txt`: symlinks (they point at
paths the new machine will not have) and files over `JARVOS_SYNC_MAX_FILE_MB`
(default 5) — compiled binaries and media belong in a package, not a dotfile repo.

## The profile repo

```
jarvos-profile.json      schema, tool version, counts
packages/explicit.txt    explicit packages the distro does not provide
packages/aur.txt         the foreign subset of those (installed with yay)
packages/uv-tools.txt    uv tools no module's [post] installs
dotfiles/                home-relative files that differ from the baseline
units/{system,user}.txt  units enabled beyond the JarvOS defaults
dconf/user.dconf         dconf dump
secrets.manifest         NAMES of what must come from your vault, never values
notes.txt                what was deliberately left behind, and why
README.md
```

The capture is **deterministic** — no timestamps — so a re-capture that found
nothing new produces no diff, `status` is meaningful, and `push` only commits
real changes.

### `secrets.manifest`

A shopping list, never a container. It holds the fixed entries from
`system/continuity/secrets.manifest.in` (annotated *present* or *absent* on the
source machine), the environment variable **names** the synced dotfiles
reference, and any file the content gate refused. No value from any of them ever
enters the repo, the staging tree, or a log line.

## Restore

Four idempotent phases: **packages → dotfiles → units → post**.

* Packages: only what `pacman -Qq` says is missing; repo packages via `pacman -S
  --needed`, foreign ones via `yay -S --needed`. Then the uv tools, skipping any
  already installed. A uv tool that will not install **warns and the phase
  carries on** — a missing dev tool is not worth failing a machine rebuild over —
  and only tools that actually installed are counted as new. One that failed is
  still missing, so the next `restore` tries it again. If `uv` itself is not on
  the box the whole pass is skipped with a warning naming how many tools it left.
* Dotfiles: a file already byte-identical is skipped. A file that would be
  overwritten is first copied to `~/.jarvos-sync-backup/<timestamp>/` — pass
  `--force` to overwrite without a backup, or `--dry-run` to see the list and
  change nothing.
* Units: `systemctl enable` only for units not already enabled.
* Post: `dconf load`, then it prints exactly what still needs a secret.

Host-specific state is never restored: the new machine regenerates
`monitors.conf`, the wallpaper colours and its own machine-id.

`--dry-run` is a true preview: it reads the profile from a temporary clone and
never touches the working copy at `JARVOS_SYNC_DIR`, so previewing someone
else's repo cannot cost you your own. The only trace it leaves is whatever
`uv tool list` scaffolds inside uv's own cache.

Running `restore` twice reports `packages: 0 new, uv tools: 0 new, dotfiles: 0
changed, units: 0 enabled` and takes no backup. A uv tool that failed to install
is genuinely still missing, so a later run retries it — and warns again — rather
than silently forgetting it.

## Progress contract (JarvOS Setup app)

With `--progress`, everything human-readable goes to the log and the only
channel is one JSON object, rewritten atomically on every update at
`$XDG_RUNTIME_DIR/jarvos-sync/progress.json` (override with
`JARVOS_SYNC_PROGRESS`). It is created before any work starts and always ends
with `status` `done` or `failed`, so the panel never has to guess whether the
tool died.

```json
{
  "tool": "jarvos-sync",
  "action": "restore",          // init | push | status | restore | capture
  "status": "running",          // running | done | failed
  "phase": "packages",          // packages | dotfiles | units | post
  "phase_index": 1, "phase_total": 4,
  "step": 12, "step_total": 0,  // step_total 0 = unknown
  "message": "installing feroxbuster",
  "exit_code": null,            // integer once status != running
  "log": "~/.local/state/jarvos/jarvos-sync-restore.log",
  "secrets_manifest": "…/secrets.manifest",
  "updated": "2026-08-18T12:00:00Z"
}
```

The Setup app's two doors call `jarvos-sync restore <url> --progress` and
`jarvos-sync init [--repo NAME] --progress`; both exit non-zero on failure.

## Environment

| Variable | Default |
|---|---|
| `JARVOS_ROOT` | `/usr/share/jarvos`, `~/JarvOS`, then the checkout |
| `JARVOS_SYNC_DIR` | `~/.local/share/jarvos/profile` |
| `JARVOS_SYNC_PROGRESS` | `$XDG_RUNTIME_DIR/jarvos-sync/progress.json` |
| `JARVOS_SYNC_MAX_FILE_MB` | `5` |

## Without GitHub

`gh` is only needed for `init --repo NAME`. Any git remote works:

    jarvos-sync init --local /mnt/pendrive/jarvos-profile.git
    jarvos-sync restore /mnt/pendrive/jarvos-profile.git
