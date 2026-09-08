# Native shell operations

Start and control the original JarvOS shell:

```sh
jarvos-shell start
jarvos-shell status
jarvos-shell restart
jarvos-shell ipc jarvos panel launcher toggle
jarvos-desktop shell controlCenter open
```

The user service starts `jarvos-shell`. Both repository installers link the
two native commands into `~/.local/bin`. The Arch package installs them into
`/usr/bin` with its library and palette assets under `/usr/share/jarvos`.

Manage themes and wallpapers:

```sh
jarvos-desktop scheme list
jarvos-desktop scheme get
jarvos-desktop scheme set -n jarvos -f default
jarvos-desktop wallpaper -p /absolute/path/image.png
jarvos-desktop wallpaper -f /absolute/path/image.png
```

Preview returns palette JSON without applying it. Applying a wallpaper keeps
an explicitly selected static palette. Dynamic palettes use the selected
Material variant. The native backend writes state only after a successful
wallpaper display command.

Record the focused monitor with system audio:

```sh
jarvos-desktop record -s
jarvos-desktop record --pause
jarvos-desktop record --pause
jarvos-desktop record --stop
jarvos-desktop record --status
```

Use `-r` to select a region. `JARVOS_RECORDINGS_DIR` overrides the output
directory. Existing `CAELESTIA_RECORDINGS_DIR` preferences remain compatible.
The backend refuses to take over recordings started elsewhere.

Saved settings and palette paths retain their old names to preserve existing
preferences. `JARVOS_DESKTOP_STATE` provides an isolated state directory for
tests. It does not change which monitor awww displays a wallpaper on.

Run `tests/run-all.sh` for the project gate and `scripts/verify-shell.sh`
for additional live checks. See the [restoration decision](decisions/2026-09-08-restore-native-shell.md)
for the validation evidence and remaining limits.
