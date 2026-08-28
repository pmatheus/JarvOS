# The JarvOS agent layer

**Date:** 2026-08-26 (revised 2026-08-28)
**Status:** design approved, ready for an implementation plan
**Source:** omarchy's agent tooling (`basecamp/omarchy`, branch `quattro`), adapted

## Sumário Executivo

JarvOS already lets agents *drive* the desktop through `hypr-box`, and
`ai.module` installs the coding agents. What it has no layer for is *managing*
those agents: which are running, what each is working on, how much quota each
has left, and what to do when something fails.

omarchy solves the single-agent half of that. **JarvOS is used multi-agent** —
four agents, several running at once — so this adapts omarchy's ideas rather
than porting them, and replaces its single-default model with session tracking.

## Goal

At any moment, see which agents are running and what each is on; see remaining
quota per agent; start a new one from a picker that shows both; and hand any
failure to an agent with the facts already gathered.

## Revision note — what changed and why

The first draft was built on two wrong premises: that `Super+A` had to keep
launching Claude Desktop, and that a **single default agent** was the right
model. The chairman corrected both on 2026-08-28 — `Super+A` is unused, and the
working style is four agents concurrently: `agy`, `codex`, `claude`, `opencode`.

Consequences: omarchy's `default-agent` abstraction is dropped entirely, usage
tracking moves from a side feature to the centre, and the bar surface becomes a
live multi-agent status rather than a quota chip.

## The four agents

| Name | Command | Notes |
|---|---|---|
| `claude` | `/usr/bin/claude` | Claude Code |
| `codex` | `~/.bun/bin/codex` | |
| `opencode` | `/usr/bin/opencode` | |
| `agy` | `/usr/bin/antigravity` | **`agy` is an alias, not a binary.** Accept it as the name; resolve to `antigravity`. |

All four are installed by `system/modules/ai.module`. `claude-desktop` and
`ollama` are installed too but are not agents in this sense — the GUI app and a
model runtime respectively.

## Why session tracking cannot be process detection

The obvious approach — `pgrep` for agent names — does not work here, and this
was verified rather than assumed. On this machine `pgrep -af claude` matches:

- the user's own Claude Code session (correct)
- a `dfirmon` binary living under `~/.claude/skills/...` (a false positive from
  the path)
- transient shell wrappers containing the word in their command line

A layer that reports a DFIR monitor as a running agent is worse than no layer.
**Sessions are therefore recorded by the launcher**, not inferred.

## Architecture

### Session records

`jarvos-agent` writes a record when it starts an agent:

`$XDG_RUNTIME_DIR/jarvos/agents/<pid>.json` — `{agent, pid, cwd, started, task}`

`XDG_RUNTIME_DIR` is `/run/user/1000`: tmpfs, so records die with the login
session and no state survives a reboot to go stale.

**Liveness is derived, never maintained.** A reader checks `/proc/<pid>`; a
record whose process is gone is stale and is ignored, and may be reaped
opportunistically. There is no cleanup daemon and no exit trap to miss — an
agent killed with `SIGKILL`, a crashed terminal and a clean exit all behave
identically.

`task` is the prompt when one was given, otherwise the working directory. It
answers "what is this one on?" at a glance.

### The pieces

**`jarvos-agent <name> [--prompt TEXT]`** — launches one of the four in a
terminal, records the session. Terminal selection reuses the repo's existing
`launch_first_available.sh` idiom rather than hardcoding one.

**`jarvos-agent-sessions [--json]`** — the live sessions, stale records
filtered out. The single source the bar reads.

**`jarvos-agent-usage-<provider>`** — one display-ready JSON record per
provider. omarchy's Claude collector reconciles local transcripts under
`~/.claude/projects`, a stats cache, sessions from other agents that ran on the
same provider, and the authoritative rate limits from the provider's usage
endpoint. Start with `claude` and `codex`, which are the two with real quota
pressure.

**`jarvos-agent-pick`** — the picker behind `Super+A`. Lists the four with, for
each, whether a session is running and what quota remains. Choosing one launches
it. Quota at the moment of choosing is the point: it is exactly when the
information is useful.

**`jarvos-agent-diagnose <kind> [args]`** — gathers a failure's facts and offers
them to an agent, pointing at a skill that holds the method:

| Kind | Facts | Trigger |
|---|---|---|
| `update` | `/tmp/jarvos-update.log`, failing step, `jarvos-version` | `jarvos-update`'s `ERR` trap |
| `crash` | `coredumpctl` record: process, PID, binary, signal, time | The crash notification, or by hand |
| `migration` | Migration filename, its output, which marker is absent | `jarvos-migrate` on abort |
| `shell` | Bounded tail of `qs log -c caelestia` | A repeated shell crash |

**The method lives in the skill, not the script.** Each script gathers facts and
points at `~/.config/jarvos/agents/skills/diagnose-failure/SKILL.md`, so the
approach is edited once and works with whichever agent you hand it to. A harness
with no skill mechanism is told to read the file directly. This is the first
skill JarvOS ships.

**Bar surface** — reads `jarvos-agent-sessions` and the usage records. Shows
running agents and remaining quota. Additive; costs no keybinding.

**Command metadata** — omarchy's self-describing headers
(`# jarvos:summary=`, `args`, `examples`) across `bin/jarvos-*`. Nothing consumes
it on day one; it is what lets a menu or cheatsheet be generated later rather
than hand-maintained, and retrofitting 19 commands is cheaper than 40.

## Keybinding

`Super+A` → `jarvos-agent-pick`. One binding, not four: the keymap is 108 deep
and a picker scales to four agents without consuming four chords.

`Super+A` is currently bound to `claude-desktop-native`. The chairman does not
use it, so repointing is free — but the old binding is **removed, not kept
alongside**, since leaving a dead alternative is how a keymap rots.

## What this does NOT do

- **No change to `hypr-box`.** Agents driving the desktop is a separate layer.
- **No default agent.** Rejected as the wrong model for concurrent use.
- **No routing.** Choosing for the user needs a policy worth trusting; a wrong
  pick is more annoying than choosing yourself. Quota is shown so the human
  routes.
- **No unattended agent execution.** Every failure handoff is an offer.
- **No secrets in prompts or logs.** Usage collectors read provider auth to
  query quota endpoints; they must never print a token, and a generated prompt
  must never embed one. An update transcript can contain anything the update
  printed — treat redaction as a requirement, not a nicety. The `vault-working`
  skill applies to anything touching provider credentials.

## Sequencing

Everything except the bar surface is `bin/`, `config/.config/jarvos/` and one
line of `keybinds.conf`, and collides with nothing in flight.

**The bar surface touches `config/.config/quickshell/jarvos/modules/bar/`, where
the Caelestia removal is working.** Build the collectors and
`jarvos-agent-sessions` first — ordinary scripts with testable JSON output — and
add the bar surface once that tree settles.

## Verification

1. `Super+A` opens the picker listing all four agents.
2. Launching from the picker starts the agent and it appears in
   `jarvos-agent-sessions`.
3. Two agents launched concurrently both appear, each with its own task.
4. Killing one with `SIGKILL` removes it from the listing without cleanup.
5. `jarvos-agent-usage-claude` prints valid JSON and prints no token.
6. A deliberately failed `jarvos-update` offers a diagnose command and does not
   run it.
7. No `pgrep`-style false positive: `dfirmon` and the user's own session never
   appear as launched agents.
8. Every existing keybinding still resolves.
9. `tests/run-all.sh` passes; new scripts are shellcheck-clean.

## Open questions

- Whether the bar surface should warn actively at a quota threshold or stay
  passive.
- Whether `jarvos-agent-sessions` should show elapsed time per session.
- Whether an agent launched outside `jarvos-agent` should be adopted somehow,
  or simply not tracked.
