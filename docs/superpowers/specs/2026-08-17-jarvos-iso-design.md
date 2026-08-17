# JarvOS ISO — design spec

Date: 2026-08-17 · Status: approved by chairman (see decisions) · Owner: pmatheus

## Goal

The easiest and fastest way to install Arch Linux with the full JarvOS
desktop already instrumented (Hyprland + QuickShell shell + hypr-box agent
control layer + apps + security toolkit). Boot an ISO, answer a short wizard,
reboot into the finished desktop. Same scheme DHH used for Omarchy
(omarchy.org / omacom-io/omarchy-iso, MIT).

## Decisions (chairman, 2026-08-17)

| Topic | Decision |
|---|---|
| ISO architecture v1 | **Online**: archiso + gum configurator + archinstall; packages fetched from Arch mirrors / AUR at install time. Offline mirror = phase 2. |
| Default profile | **`full`** (core desktop + apps + security/RE toolkit + optional services). `apps` and `core` selectable in wizard. |
| Repo | New **`pmatheus/jarvos-iso`** (MIT). `pmatheus/JarvOS` stays the runtime. |
| Locale defaults | `en_US.UTF-8`, keyboard `us`, timezone asked (default UTC). |
| Disk encryption | Optional, **default ON** (LUKS via archinstall). |
| Autoinstall | **Yes** — `cidata`-labeled drive with the configurator's own output files. |
| Verification this session | QEMU: ISO boots, wizard runs, unattended `core` install completes, Hyprland/SDDM up. `full` validated by package dry-run only (disk limit). |
| Hosting | GitHub Releases (`gh release upload`), site on GitHub Pages in the same repo. |
| Installer approach | **A**: gum wizard → archinstall JSON → `archinstall --silent` → chroot runs JarvOS `bootstrap.sh`. |

Rejected: pure-bash installer (reimplements disks/LUKS/bootloader), Python
orchestrator à la Omarchy 4 (overkill for v1).

## Repository layout — `pmatheus/jarvos-iso`

```
bin/
  jarvos-iso-make        build ISO (native mkarchiso) → release/jarvos-<ver>.iso + .sha256
  jarvos-iso-boot        boot an ISO in QEMU/OVMF with a blank virtio disk (manual test)
  jarvos-iso-test        unattended install via cidata + boot + SSH assertions
  jarvos-iso-release     gh release create <ver> with ISO, sha256, notes
configs/                 archiso profile (derived from releng)
  profiledef.sh          iso_name=jarvos, file_permissions for every executable
  packages.x86_64        live-env packages: releng base + archinstall gum jq git
                         networkmanager openssh terminus-font
  pacman.conf
  efiboot/, grub/, syslinux/   boot menus branded "JarvOS"
  airootfs/
    root/.automated_script.sh          tty1 entry: colors → cidata? → configurator → install
    etc/systemd/system/getty@tty1.service.d/autologin.conf
    usr/local/bin/jarvos-configurator  gum wizard → /root/user_configuration.json,
                                       user_credentials.json, jarvos_profile
    usr/local/bin/jarvos-cidata-load   copy config from drive labelled cidata → /root
    usr/local/bin/jarvos-install       orchestrator: archinstall → chroot-setup → reboot
    usr/share/jarvos-iso/chroot-setup.sh   runs inside /mnt via arch-chroot
    usr/share/jarvos-iso/version
test/
  all                    runs every unit test (no VM)
  unit/*.sh              cidata-load, configurator JSON generation, chroot-setup dry-run
docs/index.html          GitHub Pages landing page
README.md, LICENSE (MIT), CREDITS.md
```

## Flow

1. **Boot** — systemd-boot/GRUB entry "JarvOS Installer" → root autologin tty1
   → `.automated_script.sh` (log to `/var/log/jarvos-install.log`, stderr to
   tty so gum renders).
2. **Network** — if no default route: offer `nmtui` (wifi) then re-check;
   abort with message if still offline (online ISO).
3. **Config** — `jarvos-cidata-load` succeeds → skip wizard. Else
   `jarvos-configurator` asks, in order: keyboard layout, timezone, target disk
   (lsblk table, red WIPE warning + typed confirmation), hostname, username,
   password ×2, full name (git), email (git), encrypt? (default yes →
   passphrase ×2), profile (`full` default | `apps` | `core`). Writes
   archinstall v3 `user_configuration.json` (btrfs, `@`/`@home` subvols,
   systemd-boot on UEFI / grub on BIOS, NetworkManager, `disk_encryption`
   block when chosen) + `user_credentials.json` (`!root_password` disabled,
   user with sudo) + `/root/jarvos_profile` + `/root/user_full_name.txt`,
   `/root/user_email_address.txt`.
4. **Install** — `jarvos-install`:
   - `archinstall --config … --creds … --silent` (pinned: version shipped on
     the ISO; test asserts JSON accepted).
   - copy `chroot-setup.sh`, profile, name/email into `/mnt/root/`.
   - `arch-chroot /mnt /root/chroot-setup.sh <user> <profile>`:
     temp `/etc/sudoers.d/99-jarvos-install` (NOPASSWD) → as user:
     `git clone --depth 1 https://github.com/pmatheus/JarvOS ~/JarvOS` →
     `bootstrap.sh --<profile>` (chroot-aware) → git name/email →
     remove temp sudoers → `systemctl enable sddm NetworkManager` →
     `/etc/jarvos-release` (version, profile, date) → copy install log.
   - Any failure → red banner, log path, drop to shell (never silent reboot).
   - Success → print `JARVOS_INSTALL_OK` (serial-visible marker), 10 s
     countdown, reboot.
5. **First boot** — SDDM → Hyprland session → JarvOS shell. Nothing else to do.

## Changes in `pmatheus/JarvOS` (surgical)

- `bootstrap.sh`: when `systemctl --user` has no manager (chroot), use
  `sudo systemctl --global enable`; skip `sudo` password prompts assumption
  (already NOPASSWD in chroot); `--security` clones `chsoares/ezpz` → `~/ezpz`
  and `chsoares/ctf.fish` → `~/ctf.fish` (what the reference box has).
- `config/.config/fish/config.fish`: `EZPZ_HOME` → `$HOME/ezpz`.
- README: link to jarvos-iso as the recommended install path.

## Testing

- Unit (`test/all`, no VM): cidata-load copies exactly the allowed files and
  refuses partial sets; configurator non-interactive mode
  (`JARVOS_CFG_*` env) emits JSON that `archinstall` validates
  (`python -c 'import archinstall…'` or `archinstall --dry-run` when
  available); chroot-setup `--dry-run` prints the exact command sequence.
- ISO build lint: every executable under `airootfs` declared in
  `profiledef.sh` `file_permissions` (Omarchy's lint, reused idea).
- Integration (`bin/jarvos-iso-test`): builds cidata.iso (profile `core`,
  no LUKS, `authorized_keys` of a throwaway test key), boots QEMU headless
  with serial log, waits for `JARVOS_INSTALL_OK`, reboots from disk, SSH:
  `systemctl is-active sddm`, `pacman -Q hyprland quickshell`,
  `test -f ~/.config/quickshell/jarvos/shell.qml`, `cat /etc/jarvos-release`.
- Manual: `bin/jarvos-iso-boot` + screenshots of wizard and desktop for the
  README.

## Release & site

- `bin/jarvos-iso-release vX.Y.Z`: verifies clean tree, tags, builds if
  needed, `gh release create` with `jarvos-X.Y.Z.iso` (<2 GB) + `.sha256` +
  generated notes.
- `docs/index.html`: single page — name, one-line pitch, Download button
  (latest release), `dd`/Ventoy instructions, "already on Arch?" one-liner
  (`bash <(curl -fsSL https://raw.githubusercontent.com/pmatheus/JarvOS/main/bootstrap.sh) --full`),
  screenshots, credits.
- README + CREDITS: Omarchy/DHH (install scheme, MIT), archiso, archinstall,
  Caelestia (shell design system), END-4/dots-hyprland, chsoares/hypr-arch
  (ancestor of JarvOS), chsoares/ctf.fish, chsoares/ezpz.

## Out of scope (phase 2+)

Offline embedded mirror; `[jarvos]` pacman repo with prebuilt AUR (this is
what removes AUR compilation from the critical path); Secure Boot; aarch64;
dual-boot alongside Windows; Tailscale/SSH provisioning beyond
`authorized_keys`.

## Known risks

- Install time for `full` = download + AUR compilation (tens of minutes to
  hours). Documented on the site; phase 2 fixes.
- archinstall schema drift → pinned by ISO build; unit test guards.
- Some `--security` AUR packages may fail → bootstrap is best-effort there,
  install still succeeds.
