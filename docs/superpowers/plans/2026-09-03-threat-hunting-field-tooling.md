# JarvOS Threat Hunting & DFIR Field Tooling Implementation Plan

> **Goal:** Deliver an integrated, 100% offline-ready threat hunting and digital forensics layer for JarvOS in field equipment, featuring case context management, volatile triage collection, offline IOC extraction/defanging, and agent handoff.

---

## Tasks

### Task 1: Case Context Manager (`bin/jarvos-case`)
- **Deliverable:** `bin/jarvos-case`
- **Features:**
  - Root directory discovery (`$JARVOS_CASES_DIR`, `/home/user/hd10tb/cases`, `~/cases`)
  - Subcommands: `list [--json]`, `active [--path]`, `select [name]`, `new <name>`, `path <name>`
  - State persistence in `$XDG_STATE_HOME/jarvos/case/active`
- **Tests:** `tests/jarvos-hunt.test.sh` (case discovery, active switch, scaffolding)

### Task 2: Live Field Triage Collector (`bin/jarvos-hunt-triage`)
- **Deliverable:** `bin/jarvos-hunt-triage`
- **Features:**
  - Collects volatile system state: processes, deleted-exe memory mapping, sockets, cron, systemd units, shell init, user logins, listening binary hashes
  - Outputs structured `triage-<hostname>-<timestamp>.json` and `.tar.gz` into case evidence directory (or `/tmp` if no case)
  - Supports `--dry-run` and `--json`
- **Tests:** Verify artifact collection and json structure

### Task 3: IOC Extractor & Defanger (`bin/jarvos-hunt-ioc`)
- **Deliverable:** `bin/jarvos-hunt-ioc`
- **Features:**
  - `extract <file>`: regex parser for IPv4, IPv6, SHA256, MD5, URLs, domains
  - `defang <string>`: defangs IP addresses and URLs safely
  - `add <ioc> [--case <name>]`: adds to case `iocs/` directory
- **Tests:** Verify extraction patterns and defanging

### Task 4: Expand Agent Diagnostics (`bin/jarvos-agent-diagnose`)
- **Deliverable:** Update `bin/jarvos-agent-diagnose`
- **Features:**
  - `jarvos-agent-diagnose hunt [case]`: frames case investigation prompt with `threat-hunt` / `linux-threat-hunt` skill
  - `jarvos-agent-diagnose triage <triage_json>`: analyzes volatile triage anomalies
- **Tests:** Update `tests/jarvos-agent.test.sh`

### Task 5: Quickshell UI Integration
- **Deliverable:** Update `config/.config/quickshell/jarvos/modules/bar/popouts/Agents.qml`
- **Features:**
  - Displays Active Case header badge in the AI popout
  - Button to launch selected agent in active case directory
  - One-click trigger for live triage collection

### Task 6: Verification
- Run `./tests/jarvos-hunt.test.sh`
- Run `./tests/run-all.sh` (all suites green)
- Live verification in Quickshell
