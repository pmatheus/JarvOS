---
name: diagnose-failure
description: Use when diagnosing a failed JarvOS update, system crash, migration error, or shell issue.
---

# Diagnose Failure

If your agent harness has no native skill mechanism, read this file directly and follow its procedure.

## Procedure

1. **Read the Evidence First:**
   - For updates: Inspect the transcript at `/tmp/jarvos-update.log` or the specified log path.
   - For crashes: Inspect `coredumpctl info <pid>` and process logs.
   - For migrations: Check which migration script failed and the absent marker in `~/.local/state/jarvos/migrations`.
   - For shell errors: Check `journalctl --user -u quickshell-jarvos.service -n 100` or `qs log -c caelestia`.

2. **Locate the True Cause:**
   - Do not stop at the last error line (often a generic exit status).
   - Trace backwards to the earliest failed command or syntax/type error.
   - Distinguish an upstream package/network failure from a JarvOS code regression.

3. **Verify Safety Before Retrying:**
   - `jarvos-update` is designed to resume safely once underlying issues are fixed.
   - Migrations retry automatically on the next run.
   - Never re-run a failing script blindly in an infinite loop without fixing the root cause.
