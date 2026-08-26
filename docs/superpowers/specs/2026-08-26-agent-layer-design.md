# The JarvOS agent layer

**Date:** 2026-08-26
**Status:** design approved, ready for an implementation plan
**Source:** omarchy's agent tooling (`basecamp/omarchy`, branch `quattro`), adapted

## Sumário Executivo

JarvOS already lets agents *drive* the desktop through `hypr-box`, and
`ai.module` installs four coding agents plus a local model runtime. What it has
no layer for is *managing* those agents: which one is yours, how much quota is
left, and what to do when something fails.

omarchy solves exactly that half and solves nothing of the half JarvOS already
has. The two are complementary, so this adopts omarchy's agent-management layer
without touching `hypr-box`.

## Goal

One switchable default agent, visible quota, a prompt that starts work rather
than opening a tool, and any failure — a crash, a failed update, a failed
migration — offerable to that agent with the facts already gathered.

**Constraint, and the reason this design is shaped as it is:** the existing
keymap has 108 bindings and the setup is in daily use. Nothing here may break a
shortcut or a workflow that works today.

## What exists to build on

| Piece | Where | Relevance |
|---|---|---|
| `hypr-box` | uv tool, 40+ subcommands | Agents controlling the desktop. **Untouched by this work.** |
| Installed agents | `system/modules/ai.module` | claude-code, opencode, openai-codex, antigravity, ollama, claude-desktop |
| `Super+A` | `keybinds.conf` | Hardcoded to `claude-desktop-native`. Repointed here. |
| `jarvos-update`'s `ERR` trap | `bin/jarvos-update:81` | Already prints where the transcript is. The handoff hooks in here. |
| `~/.config/jarvos/hooks/` | shipped | Establishes `~/.config/jarvos/` as the user surface. `defaults/` and `agents/` are siblings. |
| Topbar chips | `modules/bar/` | Tailscale and network chips are the working pattern for a usage chip. |

## The five pieces

### 1. Default-agent abstraction

`jarvos-default-agent [<name>]` prints the current choice, or sets it. Stored at
`~/.config/jarvos/defaults/agent`.

Supported names map to what `ai.module` actually installs — `claude`,
`opencode`, `codex`, `antigravity` — plus `claude-desktop` for the GUI. **Ship
with `claude-desktop` as the default**, because that is what `Super+A` does
today and the muscle memory must survive the change.

Unlike omarchy, which deliberately ships no default and makes you choose, JarvOS
has an existing behaviour to preserve. Preserving it is the point.

### 2. `jarvos-agent` — the launcher

`jarvos-agent [--pick] [--prompt TEXT]` launches the default agent. GUI agents
are launched directly; CLI agents open in a terminal.

`Super+A` is repointed from `claude-desktop-native ...` to `jarvos-agent`.
With the default set to `claude-desktop`, the key does exactly what it does
today — and gains a switch.

Borrowed from omarchy, because the reason is real: agents refuse to remember
trust for `$HOME`, so a launch from a keybinding starts in a work directory
rather than re-prompting every session. JarvOS's equivalent is `~/JarvOS` or
the user's configured work path, not omarchy's hardcoded `~/Work`.

### 3. `jarvos-agent-prompt` — start work, not a tool

Takes a prompt and hands it to the default agent via `jarvos-agent --prompt`.
Reachable from the launcher, so it needs no keybinding of its own.

### 4. Usage and quota

`jarvos-agent-usage-<provider>` prints one display-ready JSON record per
provider; a topbar chip reads that JSON and nothing else. omarchy's Claude
collector reconciles local transcripts under `~/.claude/projects`, a stats
cache, sessions from other agents that ran on the same provider, and the
authoritative rate limits from the provider's usage endpoint.

**Start with Claude and Codex.** Those are the two with real quota pressure, and
the value is knowing before a long session that it will not survive to the end.

The chip is additive and costs no keybinding, which is why it is the piece that
best fits the constraint.

### 5. Failure handoff

The most valuable piece, and the one JarvOS is best positioned for because the
failures are already instrumented.

`jarvos-agent-diagnose <kind> [args]` gathers the facts for a failure and hands
them to the default agent, pointing at a skill that holds the method:

| Kind | Facts gathered | Trigger |
|---|---|---|
| `crash` | `coredumpctl` record: process, PID, binary, signal, time | The "Process crashed" notification, or by hand |
| `update` | `/tmp/jarvos-update.log`, the failing step, `jarvos-version` | `jarvos-update`'s `ERR` trap offers it |
| `migration` | The migration filename, its output, which marker is absent | `jarvos-migrate` on abort |
| `shell` | `qs log -c caelestia` tail, the QML error | A repeated shell crash |

**The method lives in the skill, not the script.** Each script gathers facts and
points at `~/.config/jarvos/agents/skills/<name>/SKILL.md`. That way the
approach is edited in one place, works with whichever agent is default, and a
harness with no skill mechanism can be told to read the file directly.

This is the first skill JarvOS ships. `config/.config/jarvos/agents/skills/`
is the home, mirroring the `hooks/` convention already established.

**Offer, never act.** A failure handoff proposes; it does not run an agent
unattended against a broken machine. `jarvos-update`'s trap prints the command
rather than executing it.

### 6. Command metadata

Adopt omarchy's self-describing header convention across `bin/jarvos-*`:

```bash
# jarvos:summary=Apply the one-time repair scripts a release ships
# jarvos:args=[--pending] [--mark-all] [--adopt]
# jarvos:examples=jarvos-migrate --pending
```

Nothing consumes it on day one. It is what lets a menu, a cheatsheet, or an
agent-facing command index be generated later rather than hand-maintained — and
retrofitting 19 commands is cheaper now than after there are 40.

## What this does NOT do

- **No change to `hypr-box`.** Agents driving the desktop is JarvOS's own layer
  and is out of scope.
- **No new keybindings.** `Super+A` is repointed, nothing is added. The keymap
  is 108 bindings deep and every addition is a future collision.
- **No unattended agent execution.** Every handoff is an offer.
- **No secrets in prompts.** Usage collectors read provider auth to query quota
  endpoints; they must never print a token, and a generated prompt must never
  embed one. The `vault-working` skill applies to anything touching provider
  credentials.

## Sequencing — one real conflict

Pieces 1, 2, 3, 5 and 6 are `bin/`, `config/.config/jarvos/` and one line of
`keybinds.conf`. They do not collide with anything in flight.

**Piece 4's topbar chip touches `config/.config/quickshell/jarvos/modules/bar/`,
which is where the Caelestia removal Parts 2-3 will work.** Build the collectors
first — they are ordinary scripts with testable JSON output — and add the chip
once the removal has settled that tree, or accept the merge cost knowingly.

## Verification

1. `Super+A` with the default unset or set to `claude-desktop` launches Claude
   Desktop exactly as it does today.
2. `jarvos-default-agent codex` then `Super+A` opens Codex in a terminal.
3. `jarvos-agent-usage-claude` prints valid JSON, and prints no token.
4. A deliberately failed `jarvos-update` offers a diagnose command, and does not
   run it.
5. `jarvos-agent-diagnose crash <pid>` from `coredumpctl list` produces a prompt
   naming the process, signal and skill path.
6. Every existing keybinding still resolves — no collisions introduced.
7. `tests/run-all.sh` passes; new scripts are shellcheck-clean.

## Open questions

- Which work directory a keybinding launch should `cd` to.
- Whether `ollama` belongs in the default-agent list, being a runtime rather
  than an agent.
- Whether the usage chip should warn actively at a quota threshold or stay
  passive.
