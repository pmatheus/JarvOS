# JarvOS Threat Hunting & DFIR Field Tooling Spec

**Date:** 2026-09-03  
**Status:** In Progress  
**Author:** Pair programming with Chairman  

## 1. Vision & Background

JarvOS is an opinionated Arch-based operating system designed for field equipment, threat hunting, and digital forensics. In field operations, analysts and incident responders require:
1. **Deterministic, 100% offline-capable artifact collection**: Live memory and volatile system state triage without cloud dependencies.
2. **Active Case Context Management**: Automatic tracking of which engagement or case is active (`tci_2026`, `mte`, etc.) and tying terminal workflows to it.
3. **Offline IOC Extraction & Defanging**: Rapid identification and defanging of hashes, IP addresses, domains, and network indicators.
4. **Seamless AI Agent Handoff**: Feeding gathered case facts, forensic snapshots, and IOCs directly into autonomous agents (`claude`, `codex`, `opencode`, `agy`) equipped with specialized threat-hunting skills (`linux-threat-hunt`, `windows-threat-hunt`, `threat-hunt`).

---

## 2. Component Design

### 2.1 Case Context Manager (`bin/jarvos-case`)

- **Root Case Discovery:**
  Automatically looks for case directories in:
  1. `$JARVOS_CASES_DIR` (if set)
  2. `/home/user/hd10tb/cases` (if mounted)
  3. `$HOME/cases` (fallback default)
- **Subcommands:**
  - `jarvos-case list [--json]`: Lists discovered cases, their path, last modified date, and active status.
  - `jarvos-case active [--path]`: Returns the currently selected active case name or full path.
  - `jarvos-case select [name]`: Selects the active case. If `name` is omitted, opens an interactive Fuzzel or terminal picker. Persists choice to `$XDG_STATE_HOME/jarvos/case/active`.
  - `jarvos-case new <name>`: Scaffolds a new standard case directory hierarchy:
    ```
    <case_dir>/
      ├── artifacts/      # Extracted binaries, memory dumps, PCAPs
      ├── evidence/       # Forensic images, triage archives
      ├── hunt/           # Hunt hypotheses, search queries, notes
      ├── iocs/           # Extracted IOCs (ips.txt, hashes.txt, domains.txt)
      └── reports/        # Executive and technical reports
    ```
  - `jarvos-case path [name]`: Prints the resolved absolute directory path of a case.

### 2.2 Live Field Triage Collector (`bin/jarvos-hunt-triage`)

- **Purpose:** Collects live forensic volatile artifacts from a running host with minimal footprint and zero external network calls.
- **Output:** Saves to `<active_case_dir>/evidence/triage/triage-<hostname>-<timestamp>.json` and `.tar.gz`.
- **Artifacts Collected:**
  1. **System Metadata**: Hostname, kernel version, boot time, uptime, date, active IP interfaces and routing table.
  2. **Process State**: Full process list (`ps auxwwf`), running binaries with deleted disk images (`/proc/*/exe -> (deleted)`), raw socket listeners.
  3. **Network Sockets**: Active and listening TCP/UDP sockets (`ss -tupna`).
  4. **Persistence Mechanisms**:
     - System & user cron tabs (`/etc/cron*`, `/var/spool/cron/*`)
     - Systemd timer and service units (`systemctl list-timers --all`, `/etc/systemd/system/`, `~/.config/systemd/user/`)
     - Shell initialization scripts (`/etc/profile.d/`, `~/.bashrc`, `~/.zshrc`)
     - Dynamic linker preloads (`/etc/ld.so.preload`)
  5. **Users & Auth**: Current logged-in users, `last` login records, `/etc/passwd` accounts with shell access.
  6. **Kernel Modules**: Loaded module list (`lsmod`).
  7. **Listening Binary Hashes**: SHA256 hashes of binaries listening on network sockets.

### 2.3 Field IOC Extractor & Defanger (`bin/jarvos-hunt-ioc`)

- **Purpose:** Fast offline parser that extracts and defangs indicators of compromise from files, logs, or command output.
- **Subcommands:**
  - `jarvos-hunt-ioc extract <file>`: Parses IPv4, IPv6, MD5, SHA1, SHA256, URLs, and domains.
  - `jarvos-hunt-ioc defang <string>`: Converts indicators into safe notation:
    - `1.1.1.1` -> `1[.]1[.]1[.]1`
    - `http://evil.com` -> `hxxp://evil[.]com`
  - `jarvos-hunt-ioc add <ioc> [--case <name>]`: Appends an IOC to the case's `iocs/` list with timestamp and source.

### 2.4 Agent Diagnostic & Hunt Handoff (`bin/jarvos-agent-diagnose`)

- Expands `jarvos-agent-diagnose` to support:
  - `jarvos-agent-diagnose hunt [case]`: Gathers active case overview, recent triage outputs, and findings, framing an investigation prompt referencing the `threat-hunt` / `linux-threat-hunt` skill.
  - `jarvos-agent-diagnose triage <triage_json>`: Synthesizes volatile triage findings into a prioritized anomaly briefing for the agent.

### 2.5 Quickshell UI Integration

- In `Agents.qml`:
  - Adds an **Active Case** section showing the currently active case (e.g. `mre/tci_2026`).
  - Provides a quick action button: `+ Launch Agent in Case` which opens the selected agent directly in the case's root directory.

---

## 3. Verification Plan

1. **Test Suite (`tests/jarvos-hunt.test.sh`):**
   - Case discovery in multiple search paths.
   - Active case switching and persistence.
   - New case directory scaffolding.
   - Triage artifact gathering in sandbox mode.
   - IOC extraction and defanging.
   - Agent diagnose handoff for hunt and triage.
2. **Quickshell Integration:**
   - Active case renders correctly in `Agents.qml`.
   - Launching agent in case starts terminal with `cwd` set to case path.
