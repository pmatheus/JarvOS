# Agent Layer and Quickshell Bar Chip — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development and superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-08-26-agent-layer-design.md` (revised 2026-08-28 for concurrent multi-agent use).

**Goal:** Implement the multi-agent management layer: CLI session tracking, launcher, `Super+A` picker, diagnostic handoff, and a Quickshell bar chip with a popout showing live sessions.

**Architecture:**
- **Track 1 (CLI & Backend):** `bin/jarvos-agent`, `bin/jarvos-agent-sessions`, `bin/jarvos-agent-pick`, `bin/jarvos-agent-diagnose`, `config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md`, `tests/jarvos-agent.test.sh`.
- **Track 2 (Desktop & Keybinds):** `config/.config/hypr/hyprland/keybinds.conf` (`Super+A` -> `jarvos-agent-pick`).
- **Track 3 (Quickshell UI):** `config/.config/quickshell/jarvos/modules/bar/components/AgentStatus.qml`, `config/.config/quickshell/jarvos/modules/bar/popouts/Agents.qml`, and registration in `Bar.qml`.

---

## Global Constraints

- **Never break an existing keybinding.** Repoint `Super+A` from `claude-desktop-native` to `jarvos-agent-pick`.
- **No false positives.** Never match `dfirmon`, shell wrappers, or child helpers like `--chrome-native-host`.
- **Support both explicit records and safe live adoption.** Sessions recorded in `$XDG_RUNTIME_DIR/jarvos/agents/<pid>.json` take priority; unrecorded live agents running on the machine (`claude`, `codex`, `opencode`, `agy`/`antigravity`) are also discovered so current sessions immediately appear in the bar.
- **Offer, never act.** Diagnostic handoff prints the command; it never runs an agent unattended.
- **No secrets in prompts or logs.**
- **All tests must pass:** `tests/run-all.sh` (bash suites, QML suites, shellcheck).

---

## Plan Tasks

### Task 1: `jarvos-agent-sessions` & Session Discovery

- [ ] **Step 1: Write failing test in `tests/jarvos-agent.test.sh`**
  - Verify `jarvos-agent-sessions` returns empty when no sessions or agents are running in sandbox.
  - Verify `jarvos-agent-sessions` reads recorded `$XDG_RUNTIME_DIR/jarvos/agents/<pid>.json`.
  - Verify stale records (where `/proc/<pid>` does not exist) are reaped.
  - Verify `--json` outputs a valid JSON array of session objects.
- [ ] **Step 2: Run test and observe failure**
- [ ] **Step 3: Implement `bin/jarvos-agent-sessions`**
  - Read records from `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/jarvos/agents/`.
  - Check process existence via `/proc/<pid>`. Reap stale files.
  - Discover unrecorded live agent processes (`claude`, `codex`, `opencode`, `agy`/`antigravity`) excluding `--chrome-native-host`.
  - Format output as human-readable table or JSON (`--json`).
- [ ] **Step 4: Run tests and verify PASS**
- [ ] **Step 5: Commit `bin/jarvos-agent-sessions` and `tests/jarvos-agent.test.sh`**

---

### Task 2: `jarvos-agent` Launcher

- [ ] **Step 1: Add failing tests to `tests/jarvos-agent.test.sh`**
  - Test canonical agent name resolution (`claude`, `codex`, `opencode`, `antigravity`/`agy`).
  - Test `--prompt <text>` handling.
  - Test terminal selection and record creation in sandbox `$XDG_RUNTIME_DIR/jarvos/agents/`.
  - Test missing/invalid agent rejection.
- [ ] **Step 2: Run test and observe failure**
- [ ] **Step 3: Implement `bin/jarvos-agent`**
  - Canonicalize agent names.
  - Pick terminal using `launch_first_available.sh` logic.
  - Launch agent in terminal and record `$XDG_RUNTIME_DIR/jarvos/agents/<pid>.json`.
- [ ] **Step 4: Run tests and verify PASS**
- [ ] **Step 5: Commit `bin/jarvos-agent`**

---

### Task 3: `jarvos-agent-pick` and `Super+A` Keybinding

- [ ] **Step 1: Add test in `tests/jarvos-agent.test.sh`**
  - Verify `jarvos-agent-pick --list` lists the 4 agents with active session count.
  - Verify keybinds.conf maps `Super, A` to `jarvos-agent-pick`.
- [ ] **Step 2: Implement `bin/jarvos-agent-pick`**
  - Present Fuzzel dmenu if graphical, or terminal fzf/select if CLI.
  - Selecting an agent runs `jarvos-agent <name>`.
- [ ] **Step 3: Update `config/.config/hypr/hyprland/keybinds.conf`**
  - Change `Super, A` to execute `jarvos-agent-pick`.
- [ ] **Step 4: Run tests and verify PASS**
- [ ] **Step 5: Commit `bin/jarvos-agent-pick` and `keybinds.conf`**

---

### Task 4: `jarvos-agent-diagnose` and Diagnostic Skill

- [ ] **Step 1: Add tests for `jarvos-agent-diagnose` in `tests/jarvos-agent.test.sh`**
  - Test `update`, `crash`, `migration`, `shell` kinds.
  - Test `--dry-run` prints prompt without executing.
  - Test skill file presence.
- [ ] **Step 2: Create `config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md`**
- [ ] **Step 3: Implement `bin/jarvos-agent-diagnose`**
- [ ] **Step 4: Wire diagnostic suggestion into `bin/jarvos-update` `ERR` trap**
- [ ] **Step 5: Run tests and verify PASS**
- [ ] **Step 6: Commit diagnostics**

---

### Task 5: Quickshell Bar Chip & Popout

- [ ] **Step 1: Create `modules/bar/components/AgentStatus.qml`**
  - Polls `jarvos-agent-sessions --json` or uses file watcher / process timer.
  - Shows agent icon (`neurology` or `smart_toy`) and active session count badge.
  - Visible when ≥ 1 session is active (or always visible with 0 count depending on config).
  - Clicking opens the `agents` popout.
- [ ] **Step 2: Create `modules/bar/popouts/Agents.qml`**
  - Lists running sessions (agent name, PID, working directory, task).
  - Quick action buttons to launch agents or switch to their windows.
- [ ] **Step 3: Register `agentStatus` in `modules/bar/Bar.qml` and `modules/bar/BarWrapper.qml` / config**
- [ ] **Step 4: Deploy to `~/.config/quickshell/jarvos` and reload Quickshell**
- [ ] **Step 5: Commit Quickshell UI changes**

---

## Verification

1. `jarvos-agent-sessions` displays all running agent sessions on the machine without false positives.
2. `jarvos-agent codex` creates a record in `$XDG_RUNTIME_DIR/jarvos/agents/` and starts the agent.
3. `jarvos-agent-pick` presents the agents and launches the chosen one.
4. `jarvos-agent-diagnose update --dry-run` produces an actionable diagnosis prompt.
5. Quickshell bar displays the active agent count chip and the popout renders active sessions.
6. Full test suite `./tests/run-all.sh` passes cleanly with 0 failures and 0 shellcheck errors.
