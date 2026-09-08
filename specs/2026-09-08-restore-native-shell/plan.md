# Restoration and native backend

The user explicitly authorized this restoration and continuation. These
artifacts record the accepted direction and executed work, not a new gate.

A1. Revert the Omarchy migration and restore original QML configuration.
A2. Implement native CLI services and retain existing QML contracts.
A3. Validate on the live desktop, check package lists and save local commits.

## Verification

- [x] Original bar visually restored and native IPC responds.
- [x] Launcher creates a Kitty window and Settings opens.
- [x] Real recording starts, pauses, resumes and produces valid video/audio.
- [x] Real awww wallpaper application passes with isolated test state.
- [x] Live saved palette remains unchanged by validation.
- [x] Visualizer produces frames and releases the final consumer.
- [x] Backend tests, full project gate and local lint/type checks pass.
- [x] Caelestia packages are absent and package lists omit them.

The external read-only review could not run because of its session quota.
Existing optional file-index and settings-icon warnings are documented in
`docs/decisions/2026-09-08-restore-native-shell.md`.
