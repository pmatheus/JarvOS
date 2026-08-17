# JarvOS ISO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `pmatheus/jarvos-iso` — a bootable Arch ISO that installs the full JarvOS desktop after a short `gum` wizard (Omarchy scheme), verified end-to-end in QEMU, released on GitHub with a landing page.

**Architecture:** archiso `releng`-derived profile; tty1 autologin runs `.automated_script.sh` → `jarvos-cidata-load` (autoinstall) or `jarvos-configurator` (gum wizard emitting archinstall JSON) → `jarvos-install` (`archinstall --silent`, then `arch-chroot` runs `chroot-setup.sh`, which clones `pmatheus/JarvOS` and runs `bootstrap.sh --<profile>` as the new user) → reboot into SDDM/Hyprland. Two repos: `pmatheus/JarvOS` (runtime, small chroot-aware fixes) and `pmatheus/jarvos-iso` (builder/installer/tests/site).

**Tech Stack:** bash, archiso 89 (`mkarchiso`), archinstall 4.4, gum 0.17, jq, QEMU 11 + edk2-ovmf, `gh` CLI, GitHub Pages.

Spec: `docs/superpowers/specs/2026-08-17-jarvos-iso-design.md` (in JarvOS repo).

## Global Constraints

- Online ISO v1: no embedded mirror. ISO must stay **< 2 GB** (GitHub Releases asset limit).
- Default profile **`full`**; wizard offers `full | apps | core`. Locale defaults `en_US.UTF-8` / kb `us`; timezone asked (default `UTC`).
- Disk encryption optional, **default ON**; LUKS passphrase = user password (one less prompt; documented).
- Bootloader **Grub** (JarvOS ships a GRUB theme + timeshift integration). Filesystem btrfs (`@`, `@home`, `@log`, `@pkg`, `compress=zstd`), 2 GiB ESP at `/boot`.
- Autoinstall: drive labelled `cidata` with `user_configuration.json` + `user_credentials.json` (+ optional `jarvos_profile`, `user_full_name.txt`, `user_email_address.txt`, `authorized_keys`).
- Never reboot silently on failure: red banner, log path, drop to shell.
- Every executable under `configs/airootfs` must be declared in `profiledef.sh` `file_permissions` (lint enforces).
- Style: bash `set -euo pipefail`, 4-space indent, ≤ 777 lines/file, `shellcheck` clean (`shellcheck -S warning`).
- Commits: clean what/why messages, no AI references, no Co-Authored-By.
- Secrets: none in either repo. Test SSH key generated at test time into `test-runs/`, git-ignored.
- Ground before writing: `archinstall --help`, `mkarchiso -h`, `gum <cmd> --help`, `qemu-system-x86_64 -help` — never reconstruct flags from memory.
- Workdir for the new repo: `~/jarvos-iso`.

---

## File map

### `pmatheus/JarvOS` (modify)
- `bootstrap.sh` — chroot-aware user-service enabling; install hypr-box; `--security` clones ezpz + ctf.fish.
- `install.sh:130-133` — `systemctl --user enable ydotool` chroot fallback.
- `config/.config/fish/config.fish:29` — `EZPZ_HOME` → `$HOME/ezpz`.
- `README.md` — "Install from ISO" section pointing at jarvos-iso.

### `pmatheus/jarvos-iso` (create)
```
LICENSE  README.md  CREDITS.md  .gitignore
bin/jarvos-iso-lint       profiledef file_permissions lint
bin/jarvos-iso-make       mkarchiso build → release/
bin/jarvos-iso-boot       QEMU manual boot
bin/jarvos-iso-test       QEMU unattended install + assertions
bin/jarvos-iso-release    gh release
configs/profiledef.sh  configs/packages.x86_64  configs/pacman.conf
configs/{efiboot,grub,syslinux}/…       (copied from releng, text branded)
configs/airootfs/root/.automated_script.sh
configs/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf   (releng)
configs/airootfs/usr/local/bin/jarvos-configurator
configs/airootfs/usr/local/bin/jarvos-cidata-load
configs/airootfs/usr/local/bin/jarvos-install
configs/airootfs/usr/share/jarvos-iso/chroot-setup.sh
configs/airootfs/usr/share/jarvos-iso/version          (0.1.0)
test/all
test/unit/cidata-load-test.sh
test/unit/configurator-test.sh
test/unit/chroot-setup-test.sh
test/unit/install-test.sh
docs/index.html
```

---

### Task 1: JarvOS runtime — chroot-aware bootstrap, hypr-box, ezpz/ctf.fish

**Files:**
- Modify: `~/JarvOS/bootstrap.sh`
- Modify: `~/JarvOS/install.sh:130-133`
- Modify: `~/JarvOS/config/.config/fish/config.fish:29`
- Test: `~/JarvOS/scripts/test-bootstrap-chroot.sh` (new)

**Interfaces:**
- Produces: `bootstrap.sh --core|--apps|--security|--full` (unchanged flags; `--core` added as explicit no-op alias for the default) runnable inside `arch-chroot` as the target user with passwordless sudo, network, and no user systemd manager.
- Env: `JARVOS_HOME` (default `$HOME`) used for ezpz/ctf.fish clone targets.

- [ ] **Step 1: Write the failing test** — `scripts/test-bootstrap-chroot.sh`:

```bash
#!/usr/bin/env bash
# Simulates chroot: no user manager → bootstrap must fall back to `systemctl --global enable`.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$FAKE_LOG"
[[ "$1" == "--user" ]] && { echo "Failed to connect to bus" >&2; exit 1; }
exit 0
EOF
for c in sudo yay pacman git uv; do printf '#!/usr/bin/env bash\necho "%s $*" >>"$FAKE_LOG"\n' "$c" >"$tmp/bin/$c"; done
# sudo must pass through to the fake systemctl
printf '#!/usr/bin/env bash\necho "sudo $*" >>"$FAKE_LOG"; exec "$@"\n' >"$tmp/bin/sudo"
chmod +x "$tmp/bin/"*
export FAKE_LOG="$tmp/log" PATH="$tmp/bin:$PATH" HOME="$tmp/home"
mkdir -p "$HOME"
: >"$FAKE_LOG"
bash -c 'source <(sed -n "/^enable_user_unit()/,/^}/p" bootstrap.sh); enable_user_unit ydotool.service'
grep -q -- '--global enable ydotool.service' "$FAKE_LOG" || { echo "FAIL: no --global fallback"; cat "$FAKE_LOG"; exit 1; }
grep -q 'hypr-box' bootstrap.sh || { echo "FAIL: hypr-box not installed by bootstrap"; exit 1; }
grep -q 'chsoares/ezpz' bootstrap.sh && grep -q 'chsoares/ctf.fish' bootstrap.sh || { echo "FAIL: ezpz/ctf.fish clone missing"; exit 1; }
grep -q 'EZPZ_HOME \$HOME/ezpz' config/.config/fish/config.fish || { echo "FAIL: EZPZ_HOME hardcoded"; exit 1; }
echo PASS
```

- [ ] **Step 2: Run it, expect FAIL** — `bash scripts/test-bootstrap-chroot.sh` → `FAIL: no --global fallback` (function does not exist yet; the `source` prints nothing).

- [ ] **Step 3: Implement** in `bootstrap.sh`:
  - after the `warn()` helper add:
    ```bash
    # In arch-chroot there is no user manager: `systemctl --user` cannot connect.
    # Fall back to --global (enables for all users; same effect for a fresh box).
    enable_user_unit(){
        if systemctl --user enable "$1" 2>/dev/null; then return 0; fi
        sudo systemctl --global enable "$1"
    }
    ```
  - flags loop: add `--core) ;;` (explicit alias of default).
  - services loop (`else` branch): replace `systemctl --user enable "$unit"` with `enable_user_unit "$unit"`.
  - after step 3 (install.sh) add step 3b:
    ```bash
    # 3b. hypr-box — the AI control layer (JarvOS is "AI-native")
    step "installing hypr-box (uv tool)…"
    uv tool install --force "$base/hypr-box" && ok "hypr-box installed" || warn "hypr-box install failed"
    ```
  - inside `if $SECURITY; then … fi` append:
    ```bash
    for r in ezpz ctf.fish; do
        d="${JARVOS_HOME:-$HOME}/$r"
        [[ -d "$d/.git" ]] || git clone --depth 1 "https://github.com/chsoares/$r.git" "$d" || warn "clone $r failed"
    done
    ok "ezpz + ctf.fish (chsoares) in ${JARVOS_HOME:-$HOME}"
    ```
  - `install.sh:131`: `systemctl --user enable ydotool --now 2>/dev/null || sudo systemctl --global enable ydotool 2>/dev/null || true`
  - `config.fish:29`: `set -gx EZPZ_HOME $HOME/ezpz`

- [ ] **Step 4: Run tests** — `bash scripts/test-bootstrap-chroot.sh` → `PASS`; `bash -n bootstrap.sh install.sh`; `shellcheck -S warning bootstrap.sh` (fix any new warnings you introduced only).

- [ ] **Step 5: Commit & push** (JarvOS main must be public for the chroot clone in Task 8):
```bash
cd ~/JarvOS && git add bootstrap.sh install.sh config/.config/fish/config.fish scripts/test-bootstrap-chroot.sh
git commit -m "bootstrap: chroot-aware user services, install hypr-box, clone ezpz/ctf.fish under --security"
git push origin main
```
Do NOT stage the pre-existing unrelated modifications (`custom/keybinds.conf`, `switchwall.sh`, `network-settings.sh`).

---

### Task 2: jarvos-iso repo scaffold + archiso profile + lint

**Files:**
- Create: `~/jarvos-iso/{LICENSE,README.md,CREDITS.md,.gitignore}`
- Create: `~/jarvos-iso/configs/**` (from `/usr/share/archiso/configs/releng/`)
- Create: `~/jarvos-iso/bin/jarvos-iso-lint`, `~/jarvos-iso/test/all`
- Create: `~/jarvos-iso/configs/airootfs/usr/share/jarvos-iso/version` = `0.1.0`

**Interfaces:**
- Produces: `bin/jarvos-iso-lint` (exit 0 iff every executable/`#!` file under `configs/airootfs/{root,usr/local/bin,usr/share/jarvos-iso}` is declared in `profiledef.sh` `file_permissions`); `test/all` runs `bin/jarvos-iso-lint` then every `test/unit/*.sh`.
- Profile constants used by later tasks: `iso_name="jarvos"`, `install_dir="arch"`, live packages include `archinstall gum jq git terminus-font`.

- [ ] **Step 1: Scaffold**
```bash
mkdir -p ~/jarvos-iso && cd ~/jarvos-iso && git init -b main
cp -r /usr/share/archiso/configs/releng/. configs/
rm -f configs/airootfs/usr/local/bin/{choose-mirror,Installation_guide,livecd-sound}
mkdir -p bin test/unit docs configs/airootfs/usr/share/jarvos-iso configs/airootfs/usr/local/bin
echo 0.1.0 > configs/airootfs/usr/share/jarvos-iso/version
printf 'release/\nwork/\ntest-runs/\n*.iso\n*.qcow2\n' > .gitignore
```
LICENSE: MIT, `Copyright (c) 2026 Paulo Matheus`.

- [ ] **Step 2: Edit `configs/profiledef.sh`**: `iso_name="jarvos"`, `iso_label="JARVOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"`, `iso_publisher="JarvOS <https://github.com/pmatheus/jarvos-iso>"`, `iso_application="JarvOS Installer"`, `iso_version="$(cat "${profile:-.}/airootfs/usr/share/jarvos-iso/version" 2>/dev/null || date +%Y.%m.%d)"` (verify `mkarchiso` exposes the profile dir; if not, hardcode `iso_version="0.1.0"` and let `jarvos-iso-make` sed it). `file_permissions`: keep `/etc/shadow`, `/root`, `/root/.automated_script.sh`, `/root/.gnupg`; add
```
["/usr/local/bin/jarvos-configurator"]="0:0:755"
["/usr/local/bin/jarvos-cidata-load"]="0:0:755"
["/usr/local/bin/jarvos-install"]="0:0:755"
["/usr/share/jarvos-iso/chroot-setup.sh"]="0:0:755"
```
- [ ] **Step 3: `configs/packages.x86_64`**: keep releng list; remove nothing; append `archinstall`, `gum`, `jq`, `git`, `terminus-font` (dedupe: check each with `grep -qx`). Brand boot menus: in `configs/efiboot/loader/entries/*.conf`, `configs/grub/grub.cfg`, `configs/syslinux/*.cfg` replace visible titles "Arch Linux install medium" → "JarvOS Installer" (leave `%ARCHISO_LABEL%`/paths untouched). Add `console=tty0 console=ttyS0,115200` to the kernel `options`/`APPEND` lines of the default entries so serial logs work in QEMU tests. Delete `configs/airootfs/etc/motd` content and write:
```
JarvOS installer — the wizard starts automatically on tty1.
If it does not: run  jarvos-install-start
```
and add `configs/airootfs/usr/local/bin/jarvos-install-start` = `#!/usr/bin/env bash\nexec /root/.automated_script.sh` (declare in `file_permissions`).

- [ ] **Step 4: Write `bin/jarvos-iso-lint`** (adapt Omarchy's idea):
```bash
#!/usr/bin/env bash
# Every executable shipped in airootfs must be declared in profiledef.sh file_permissions,
# otherwise mkarchiso strips the exec bit and the ISO boots into nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
declare -A declared=()
while IFS= read -r p; do declared["$p"]=1; done < <(grep -oP '^\s*\["\K[^"]+(?="\])' configs/profiledef.sh)
missing=()
while IFS= read -r f; do
    rel="${f#configs/airootfs}"
    if [[ -x "$f" || "$(head -c2 "$f")" == "#!" ]] && [[ -z "${declared[$rel]+x}" ]]; then missing+=("$rel"); fi
done < <(find configs/airootfs/root configs/airootfs/usr/local/bin configs/airootfs/usr/share/jarvos-iso -type f)
if ((${#missing[@]})); then printf 'ERROR: not in profiledef.sh file_permissions:\n'; printf '  %s\n' "${missing[@]}"; exit 1; fi
echo "lint: ok"
```
`test/all`:
```bash
#!/usr/bin/env bash
set -euo pipefail; cd "$(dirname "$0")/.."
bin/jarvos-iso-lint
rc=0; for t in test/unit/*.sh; do echo "== $t"; bash "$t" || rc=1; done; exit $rc
```
- [ ] **Step 5: Verify** — `chmod +x bin/* test/all configs/airootfs/usr/local/bin/*`; `test/all` → `lint: ok` (no unit tests yet). Deliberately create an undeclared `configs/airootfs/usr/local/bin/x` with `#!`, run lint → exit 1 listing it; delete it.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "Scaffold jarvos-iso: releng-derived archiso profile, permissions lint, test runner"`.

---

### Task 3: `jarvos-cidata-load` (autoinstall from a `cidata` drive)

**Files:**
- Create: `configs/airootfs/usr/local/bin/jarvos-cidata-load`
- Test: `test/unit/cidata-load-test.sh`

**Interfaces:**
- `jarvos-cidata-load [--source DIR]` — default source: first block device with `LABEL=cidata` (`blkid -L cidata`), mounted read-only at a temp dir. Copies into `/root` (override with `JARVOS_CIDATA_DEST` for tests) exactly the allowed files: `user_configuration.json user_credentials.json jarvos_profile user_full_name.txt user_email_address.txt authorized_keys`. Exit 0 iff both required JSON files were present and are valid JSON (`jq -e .`); exit 1 (silently, unless `--verbose`) otherwise, leaving no partial copy behind. Never prints secrets.

- [ ] **Step 1: Test** — `test/unit/cidata-load-test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail; cd "$(dirname "$0")/../.."
bin=configs/airootfs/usr/local/bin/jarvos-cidata-load
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
src="$tmp/src"; dest="$tmp/root"; mkdir -p "$src" "$dest"
export JARVOS_CIDATA_DEST="$dest"
# 1. only creds → refuse, nothing copied
echo '{"users":[]}' >"$src/user_credentials.json"
! "$bin" --source "$src" || { echo "FAIL: accepted partial set"; exit 1; }
[[ -z "$(ls -A "$dest")" ]] || { echo "FAIL: partial copy left behind"; exit 1; }
# 2. both + extras + junk → copies allowed only
echo '{"hostname":"x"}' >"$src/user_configuration.json"; echo full >"$src/jarvos_profile"; echo junk >"$src/evil.sh"
"$bin" --source "$src" || { echo "FAIL: rejected valid set"; exit 1; }
[[ -f "$dest/user_configuration.json" && -f "$dest/user_credentials.json" && -f "$dest/jarvos_profile" && ! -e "$dest/evil.sh" ]] || { echo "FAIL: wrong files copied"; ls "$dest"; exit 1; }
# 3. invalid JSON → refuse
echo '{oops' >"$src/user_configuration.json"; rm -f "$dest"/*
! "$bin" --source "$src" || { echo "FAIL: accepted invalid JSON"; exit 1; }
echo PASS
```
- [ ] **Step 2: Run** — `bash test/unit/cidata-load-test.sh` → fails (`No such file`).
- [ ] **Step 3: Implement** the script per the interface (staging dir + `mv` only after validation; `blkid -L cidata` + `mount -o ro`; `trap umount`).
- [ ] **Step 4: Run** → `PASS`; `test/all` green; `shellcheck -S warning $bin`.
- [ ] **Step 5: Commit** — `git commit -am "Add jarvos-cidata-load: unattended install config from a cidata drive"` (use `git add -A`).

---

### Task 4: `jarvos-configurator` (gum wizard → archinstall JSON)

**Files:**
- Create: `configs/airootfs/usr/local/bin/jarvos-configurator`
- Test: `test/unit/configurator-test.sh`

**Interfaces:**
- Interactive: `jarvos-configurator` asks in order: keyboard layout (`gum filter` over `localectl list-keymaps`, default `us`), timezone (`gum filter` over `timedatectl list-timezones`, default `UTC`), disk (`gum choose` over `lsblk -dpno NAME,SIZE,MODEL,TYPE | grep disk`, excluding the live medium: skip devices whose children are mounted under `/run/archiso`), typed confirmation `gum confirm --default=false "ERASE $disk completely?"`, hostname (default `jarvos`), username, password ×2 (`gum input --password`, must match, ≥ 1 char), full name, email, encrypt (`gum confirm --default=true "Encrypt disk with LUKS? (passphrase = your password)"`), profile (`gum choose full apps core`, default `full`).
- Non-interactive (tests/CI): when `JARVOS_CFG_NONINTERACTIVE=1` read `JARVOS_CFG_KEYBOARD TIMEZONE DISK HOSTNAME USERNAME PASSWORD FULLNAME EMAIL ENCRYPT(true|false) PROFILE` from env, no prompts.
- Output dir: `JARVOS_CFG_OUT` (default `/root`): `user_configuration.json`, `user_credentials.json`, `jarvos_profile`, `user_full_name.txt`, `user_email_address.txt`. Files `0600`.
- JSON template = the block below (adapted from Omarchy's configurator, MIT). Password hash: `openssl passwd -6`.

`user_configuration.json` (bash heredoc; `$disk`, `$boot_start/$boot_size/$main_start/$main_size` in bytes computed from `lsblk -bdno SIZE`, ESP = 2 GiB starting at 1 MiB, main = rest minus 1 MiB GPT backup; `$disk_encryption` = empty or the block shown):
```json
{
  "archinstall-language": "English",
  "app_config": null,
  "auth_config": {},
  "audio_config": { "audio": "pipewire" },
  "bootloader_config": { "bootloader": "Grub", "uki": false, "removable": false },
  "custom_commands": [],
  "disk_config": {
    "config_type": "default_layout",
    "device_modifications": [ {
      "device": "$disk", "wipe": true,
      "partitions": [
        { "btrfs": [], "dev_path": null, "flags": ["boot","esp"], "fs_type": "fat32", "mount_options": [],
          "mountpoint": "/boot", "obj_id": "ea21d3f2-82bb-49cc-ab5d-6f81ae94e18d",
          "size":  { "sector_size": {"unit":"B","value":512}, "unit": "B", "value": $boot_size },
          "start": { "sector_size": {"unit":"B","value":512}, "unit": "B", "value": $boot_start },
          "status": "create", "type": "primary" },
        { "btrfs": [ {"mountpoint":"/","name":"@"}, {"mountpoint":"/home","name":"@home"},
                     {"mountpoint":"/var/log","name":"@log"}, {"mountpoint":"/var/cache/pacman/pkg","name":"@pkg"} ],
          "dev_path": null, "flags": [], "fs_type": "btrfs", "mount_options": ["compress=zstd"], "mountpoint": null,
          "obj_id": "8c2c2b92-1070-455d-b76a-56263bab24aa",
          "size":  { "sector_size": {"unit":"B","value":512}, "unit": "B", "value": $main_size },
          "start": { "sector_size": {"unit":"B","value":512}, "unit": "B", "value": $main_start },
          "status": "create", "type": "primary" }
      ] } ]$disk_encryption
  },
  "hostname": "$hostname",
  "kernels": ["linux"],
  "locale_config": { "kb_layout": "$keyboard", "sys_enc": "UTF-8", "sys_lang": "en_US.UTF-8" },
  "mirror_config": { "custom_repositories": [], "custom_servers": [], "mirror_regions": {}, "optional_repositories": [] },
  "network_config": { "type": "nm" },
  "ntp": true,
  "packages": ["base-devel","git","fish","networkmanager","openssh"],
  "parallel_downloads": 8,
  "profile_config": { "gfx_driver": null, "greeter": null, "profile": {} },
  "script": null, "services": [], "swap": true,
  "timezone": "$timezone",
  "version": "4.4"
}
```
`$disk_encryption` when encrypting:
```json
,"disk_encryption": { "encryption_type": "luks", "lvm_volumes": [], "iter_time": 2000,
                      "partitions": ["8c2c2b92-1070-455d-b76a-56263bab24aa"] }
```
`user_credentials.json` (jq-escaped values; `encryption_password` line only when encrypting):
```json
{ "encryption_password": <password>, "root_enc_password": <hash>,
  "users": [ { "enc_password": <hash>, "groups": [], "sudo": true, "username": <username> } ] }
```

- [ ] **Step 1: Test** — `test/unit/configurator-test.sh`: run non-interactive with `JARVOS_CFG_DISK=/dev/loop-fake` **not allowed** — instead create a 20 GiB sparse file and use `losetup`? Requires root; keep unit test root-free: support `JARVOS_CFG_DISK_SIZE_BYTES` env override used only when set (skips `lsblk`). Assertions:
  1. both JSON files valid (`jq -e`), `jarvos_profile` = `core`, name/email files present, mode `600`;
  2. `jq -r .bootloader_config.bootloader` = `Grub`; `.disk_config.device_modifications[0].device` = `/dev/vda`; boot size = 2147483648; main start = 2148532224; `.disk_config.disk_encryption.partitions[0]` = root obj_id when `ENCRYPT=true`, and `.disk_config | has("disk_encryption")` false when `false`;
  3. creds: `.users[0].username` = `tester`, `.users[0].enc_password` starts with `$6$`, `.encryption_password` present iff ENCRYPT;
  4. **archinstall accepts it**: `uv run --python /usr/bin/python3 --no-project python -c` importing `archinstall.lib.args` and calling `ArchConfig.from_config(json.load(cfg) | json.load(creds), Arguments())` (read `args.py:255` for the exact signature; if `Arguments()` needs fields, construct with defaults) — must not raise. If archinstall's parser needs root/`/dev` access for `parse_arg`, fall back to validating with `archinstall --config … --creds … --dry-run --silent --skip-version-check --skip-ntp --skip-wifi-check --no-pkg-lookups` under `sudo` and assert exit 0 (dry-run must not touch disks; confirm from `--help`/source before running).
- [ ] **Step 2: Run** → fails (script missing).
- [ ] **Step 3: Implement** the script (gum for prompts, `jq -Rsa`/`jq -n --arg` for escaping, `openssl passwd -6`, `umask 077`).
- [ ] **Step 4: Run** → `PASS`; `test/all` green; shellcheck clean.
- [ ] **Step 5: Manual smoke** — run `JARVOS_CFG_OUT=/tmp/x jarvos-configurator` interactively once in a terminal to see gum screens render (do not pick a real disk — Ctrl-C at disk step is fine).
- [ ] **Step 6: Commit** — `git add -A && git commit -m "Add jarvos-configurator: gum wizard emitting archinstall 4.4 config"`.

---

### Task 5: `chroot-setup.sh` (runs inside the target via arch-chroot)

**Files:**
- Create: `configs/airootfs/usr/share/jarvos-iso/chroot-setup.sh`
- Test: `test/unit/chroot-setup-test.sh`

**Interfaces:**
- `chroot-setup.sh --user U --profile full|apps|core [--full-name S] [--email S] [--authorized-keys FILE] [--repo URL] [--ref REF] [--dry-run]`.
- Sequence (each line printed as `>> step` before running; `--dry-run` prints commands via a `run()` wrapper instead of executing):
  1. `printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$user" > /etc/sudoers.d/99-jarvos-install; chmod 440`
  2. `runuser -u "$user" -- git clone --depth 1 --branch "$ref" "$repo" "/home/$user/JarvOS"` (default repo `https://github.com/pmatheus/JarvOS.git`, ref `main`)
  3. `runuser -l "$user" -c "cd ~/JarvOS && ./bootstrap.sh --$profile"` — where `--core` maps to no flag → pass `--core` (Task 1 added the alias); `--full` / `--apps` pass through. Note: `--full` in bootstrap = apps+security+services.
  4. if `--full-name`/`--email`: `runuser -u "$user" -- git config --global user.name/email`.
  5. if `--authorized-keys`: install to `/home/$user/.ssh/authorized_keys` (700/600, chown), `systemctl enable sshd`.
  6. `systemctl enable sddm NetworkManager`
  7. `rm -f /etc/sudoers.d/99-jarvos-install`
  8. `printf 'JARVOS_VERSION=%s\nJARVOS_PROFILE=%s\nJARVOS_INSTALLED=%s\n' "$(cat /usr/share/jarvos-iso/version 2>/dev/null || echo unknown)" "$profile" "$(date -Is)" > /etc/jarvos-release` — the version file must be copied into the chroot by `jarvos-install` (Task 6) at `/root/jarvos-iso-version`; read that path first, fallback `unknown`.
  Exit non-zero on any failure of steps 1–3, 6 (bootstrap is `set -e`; a failing bootstrap fails the install — do not swallow).

- [ ] **Step 1: Test** — `test/unit/chroot-setup-test.sh`: run `--dry-run --user tester --profile core --full-name "T U" --email t@u --authorized-keys /dev/null` and assert output contains, in order: `sudoers.d/99-jarvos-install`, `git clone --depth 1 --branch main https://github.com/pmatheus/JarvOS.git /home/tester/JarvOS`, `bootstrap.sh --core`, `git config --global user.name`, `authorized_keys`, `systemctl enable sddm NetworkManager`, `rm -f /etc/sudoers.d/99-jarvos-install`, `/etc/jarvos-release`. Also: `--profile bogus` → exit 2 with usage.
- [ ] **Step 2: Run** → fails. **Step 3: Implement.** **Step 4: Run** → `PASS`, shellcheck clean.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add chroot-setup: clone JarvOS and run bootstrap as the new user inside the target"`.

---

### Task 6: `jarvos-install` orchestrator + `.automated_script.sh`

**Files:**
- Create: `configs/airootfs/usr/local/bin/jarvos-install`
- Replace: `configs/airootfs/root/.automated_script.sh`
- Test: `test/unit/install-test.sh`

**Interfaces:**
- `jarvos-install --config F --creds F --profile-file F [--full-name-file F] [--email-file F] [--authorized-keys-file F] [--dry-run]`. Env: `JARVOS_REPO`, `JARVOS_REF` passed through to chroot-setup; `JARVOS_MOUNT` (default `/mnt`).
- Steps (banner per step, `run()` wrapper honours `--dry-run`):
  1. network check: `curl -fsI --max-time 8 https://archlinux.org >/dev/null` else message "No network. Use `iwctl` (wifi) or plug a cable, then run jarvos-install-start" and exit 1.
  2. `archinstall --config "$config" --creds "$creds" --silent --skip-version-check` (log to `/var/log/jarvos-install.log` via `tee`).
  3. `install -Dm755 /usr/share/jarvos-iso/chroot-setup.sh "$mnt/root/chroot-setup.sh"`; `install -Dm644 /usr/share/jarvos-iso/version "$mnt/root/jarvos-iso-version"`; copy optional files into `$mnt/root/`.
  4. `arch-chroot "$mnt" /root/chroot-setup.sh --user "$(jq -r '.users[0].username' "$creds")" --profile "$(cat "$profile_file")" [--full-name …] [--email …] [--authorized-keys /root/authorized_keys] [--repo/--ref]`.
  5. `cp /var/log/jarvos-install.log "$mnt/var/log/"`; `rm -f "$mnt/root/chroot-setup.sh" "$mnt/root/authorized_keys"`.
  6. print `JARVOS_INSTALL_OK` (also `> /dev/console` and `/dev/ttyS0` if writable).
- `.automated_script.sh` (tty1 only): set terminal, `mkdir -p /var/log`, `exec > >(tee -a /var/log/jarvos-install.log) 2>/dev/tty`; `systemctl is-system-running --wait >/dev/null || true`; if `jarvos-cidata-load` → autoinstall (no prompts), else loop `jarvos-configurator` until success. Then run `jarvos-install …`; on success: `for i in 10..1: printf 'Rebooting in %s\r'`, `systemctl reboot`. On failure: red gum banner "Install failed — log: /var/log/jarvos-install.log — you are in a root shell; `jarvos-install-start` retries", then `exec bash -l`. Add `console=` friendliness: also `echo JARVOS_INSTALL_FAILED > /dev/ttyS0 2>/dev/null || true`.

- [ ] **Step 1: Test** — `test/unit/install-test.sh`: creates temp `config.json` (`{}`), `creds.json` (`{"users":[{"username":"tester"}]}`), `profile` (`core`); runs `--dry-run` with `JARVOS_MOUNT=$tmp/mnt` and stub `curl` on PATH; asserts printed sequence contains `archinstall --config … --creds … --silent`, `arch-chroot $tmp/mnt /root/chroot-setup.sh --user tester --profile core`, `JARVOS_INSTALL_OK`. Also asserts `--dry-run` without network stub prints the no-network message and exits 1 (stub `curl` returning 22).
- [ ] **Step 2: Run** → fails. **Step 3: Implement** both scripts. **Step 4: Run** → `PASS`; `test/all` green; shellcheck.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add jarvos-install orchestrator and tty1 entry script"`.

---

### Task 7: `bin/jarvos-iso-make` — build the ISO

**Files:**
- Create: `bin/jarvos-iso-make`

**Interfaces:**
- `bin/jarvos-iso-make [--work DIR] [--out DIR] [--repo URL] [--ref REF]` → `release/jarvos-<version>-x86_64.iso` + `.sha256`. Runs `bin/jarvos-iso-lint`, then `sudo mkarchiso -v -w "$work" -o "$out" configs` (`mkarchiso -h` first; check `-w`/`-o` flags). If `--repo/--ref` given, write them to `configs/airootfs/usr/share/jarvos-iso/repo` (`JARVOS_REPO=…\nJARVOS_REF=…`) before building; `.automated_script.sh` sources that file if present (add this to Task 6's script now if missing). Renames output to `jarvos-<version>-x86_64.iso`, writes sha256, prints size, fails if size ≥ 2 GiB. Cleans `work/` unless `--keep-work`.
- Sets `SOURCE_DATE_EPOCH` from `git log -1 --format=%ct` for reproducible labels.

- [ ] **Step 1**: write the script; `shellcheck`.
- [ ] **Step 2: Build for real** — `bin/jarvos-iso-make` (needs `sudo`; ~5–15 min; disk: check `df -h ~` ≥ 10 GB free first, `work/` lives under `~/jarvos-iso/work` — if `/home` is short, use `--work /var/tmp/jarvos-work`).
- [ ] **Step 3: Verify** — `ls -la release/`; `xorriso -indev release/jarvos-0.1.0-x86_64.iso -ls / 2>/dev/null` shows `arch/`, `EFI/`, `loader/`; `xorriso -osirrox on -indev … -extract /loader/entries /tmp/e` → entry text says "JarvOS Installer" and includes `console=ttyS0`. Size < 2 GiB. Extract `airootfs.sfs`? Not needed: `unsquashfs -l release/…` is heavy — instead check `mkarchiso` log lines for `jarvos-configurator` permission set (`grep -n jarvos work/…/build.log` if it exists) or trust lint + Task 8 boot.
- [ ] **Step 4: Commit** — `git add -A && git commit -m "Add jarvos-iso-make: build the ISO with mkarchiso"` (release/ is git-ignored).

---

### Task 8: QEMU harness — `jarvos-iso-boot`, `jarvos-iso-test`, real unattended `core` install

**Files:**
- Create: `bin/jarvos-iso-boot`, `bin/jarvos-iso-test`

**Interfaces:**
- `bin/jarvos-iso-boot [ISO] [--disk PATH] [--cidata ISO] [--headless] [--serial FILE] [--ssh-port N]`: creates `test-runs/disk.qcow2` (40G) if missing; copies OVMF vars (`/usr/share/edk2/x64/OVMF_VARS.4m.fd` — verify path with `pacman -Ql edk2-ovmf | grep -i vars`); runs `qemu-system-x86_64 -enable-kvm -m 6144 -smp 4 -cpu host -machine q35 -drive if=pflash,format=raw,readonly=on,file=<CODE> -drive if=pflash,format=raw,file=<vars copy> -drive file=disk.qcow2,if=virtio -cdrom ISO [-drive file=cidata.iso,media=cdrom,if=ide] -boot order=dc -netdev user,id=n,hostfwd=tcp::$PORT-:22 -device virtio-net,netdev=n -serial file:$SERIAL -no-reboot` (+ `-display none` when headless; `-vga virtio` otherwise). Fall back to no KVM if `/dev/kvm` missing (warn: slow). Ground each flag with `qemu-system-x86_64 -help`/`-device help`.
- `bin/jarvos-iso-test [ISO] [--profile core] [--encrypt] [--timeout-min 240] [--reuse-disk]`:
  1. `mkdir -p test-runs/<ts>`; `ssh-keygen -t ed25519 -N '' -f test-runs/<ts>/id`; generate configurator output via `JARVOS_CFG_NONINTERACTIVE=1 JARVOS_CFG_DISK=/dev/vda JARVOS_CFG_DISK_SIZE_BYTES=$((40*1024**3)) JARVOS_CFG_USERNAME=jarvis JARVOS_CFG_PASSWORD=jarvis JARVOS_CFG_HOSTNAME=jarvos-test JARVOS_CFG_ENCRYPT=false JARVOS_CFG_PROFILE=$profile … JARVOS_CFG_OUT=test-runs/<ts>/cidata configs/airootfs/usr/local/bin/jarvos-configurator`; copy `id.pub` → `cidata/authorized_keys`; `xorriso -as genisoimage -output cidata.iso -volid cidata -joliet -rock cidata/` (verify `genisoimage` absent → use xorriso).
  2. Boot with `jarvos-iso-boot ISO --cidata cidata.iso --headless --serial serial-install.log`; QEMU exits at reboot (`-no-reboot`). Poll `serial-install.log` for `JARVOS_INSTALL_OK` / `JARVOS_INSTALL_FAILED`; timeout → fail with tail of log.
  3. Boot again **without** cdrom (`-boot order=c`), headless, serial `serial-boot.log`; wait up to 5 min for `ssh -p PORT -i id -o StrictHostKeyChecking=no jarvis@localhost true`.
  4. Assertions over SSH: `systemctl is-active sddm` = active; `pacman -Q hyprland quickshell` (package name: check `pacman -Q | grep -i quickshell` on the reference box first — it may be `quickshell-git`; assert whichever JarvOS `dependencies.txt`/`aur-core.txt` lists); `test -f ~/.config/quickshell/jarvos/shell.qml`; `cat /etc/jarvos-release` contains `JARVOS_PROFILE=core`; `command -v hypr-box`. Save a QMP screendump of the SDDM screen: use `-qmp unix:test-runs/<ts>/qmp.sock,server,nowait` and `screendump` via `socat`/python? Simpler: `-monitor unix:…` + `echo "screendump sddm.ppm" | socat - UNIX-CONNECT:mon.sock`; convert to PNG with `magick`/`ffmpeg` if available (optional; do not fail the test on it).
  5. Print PASS/FAIL summary; exit code accordingly; keep VM logs in `test-runs/<ts>/`.

- [ ] **Step 1**: write both scripts; shellcheck.
- [ ] **Step 2: Run the real test** — `bin/jarvos-iso-test release/jarvos-0.1.0-x86_64.iso --profile core` (expect 30–90 min; run in background, poll the serial log). If it fails, **debug for real**: attach `bin/jarvos-iso-boot` non-headless to watch tty1, read `serial-install.log`, fix the offending script, rebuild ISO (`bin/jarvos-iso-make`), retry. Typical failure sources: archinstall rejecting the JSON (schema), `runuser` env (`HOME`), yay/makepkg in chroot needing `/dev/pts` (arch-chroot mounts it), `sudo` password prompt (temp sudoers), `--user systemctl` (Task 1), fish plugin curl in chroot (network is available in arch-chroot — resolv.conf is copied by arch-chroot).
- [ ] **Step 3: Evidence** — paste in the final report: last 20 lines of `serial-install.log`, SSH assertion output, `/etc/jarvos-release`, and the SDDM screenshot path if captured. Copy the screenshot into `docs/img/` for the README (only if it rendered).
- [ ] **Step 4: Commit** — `git add -A && git commit -m "Add QEMU harness: jarvos-iso-boot and unattended jarvos-iso-test"`.

---

### Task 9: Landing page, README, CREDITS

**Files:**
- Create: `docs/index.html`, `docs/img/` (screenshots from Task 8 + `~/JarvOS/screenshots/` if any)
- Write: `README.md`, `CREDITS.md`

**Interfaces:**
- `docs/index.html`: single self-contained page (inline CSS, no CDN): title "JarvOS", tagline "The AI-native Arch desktop. Boot the ISO, answer six questions, reboot into a finished system.", primary button "Download ISO" → `https://github.com/pmatheus/jarvos-iso/releases/latest`, secondary "Already on Arch?" with
  `bash <(curl -fsSL https://raw.githubusercontent.com/pmatheus/JarvOS/main/bootstrap.sh) --full`, a 3-step "Write it" block (`dd if=jarvos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync` + Ventoy/balenaEtcher mention), a "What you get" grid (Hyprland, JarvOS QuickShell shell, hypr-box AI control, security toolkit, GRUB+timeshift snapshots, LUKS default), an honest "Install time" note (online install: download + AUR builds; offline mirror planned), and a Credits footer identical to CREDITS.md. Dark theme, system font stack, responsive.
- `CREDITS.md` (also mirrored in README "Credits"):
  - **Omarchy** — DHH / Basecamp — install scheme (bootable ISO → wizard → archinstall → chroot setup), configurator JSON template adapted (MIT). https://omarchy.org · https://github.com/basecamp/omarchy · https://github.com/omacom-io/omarchy-iso
  - **archiso**, **archinstall** — Arch Linux.
  - **Caelestia** — the shell design system JarvOS is built on. https://github.com/caelestia-dots/caelestia
  - **END-4 / dots-hyprland** — Hyprland config lineage. https://github.com/end-4/dots-hyprland
  - **chsoares/hypr-arch** — the Hyprland + QuickShell base JarvOS descends from. https://github.com/chsoares/hypr-arch
  - **chsoares/ctf.fish** — CTF fish functions shipped in the security profile. https://github.com/chsoares/ctf.fish
  - **chsoares/ezpz** — pentest enumeration toolkit shipped in the security profile. https://github.com/chsoares/ezpz
- README: badges-free, sections: What / Install (ISO) / Install (existing Arch) / Autoinstall (cidata: file table from spec) / Build the ISO / Test (QEMU) / Release / Profiles table (`full|apps|core` → what each pulls from JarvOS package lists) / Roadmap (offline mirror, `[jarvos]` prebuilt repo, Secure Boot) / Credits / License.

- [ ] **Step 1**: write files; open `docs/index.html` in a browser (`xdg-open`) and check it renders (screenshot to `docs/img/site.png` optional).
- [ ] **Step 2**: `git add -A && git commit -m "Add landing page, README, credits"`.

---

### Task 10: `bin/jarvos-iso-release`, GitHub repo, Pages, v0.1.0 release, JarvOS README link

**Files:**
- Create: `bin/jarvos-iso-release`
- Modify: `~/JarvOS/README.md` (Install section)

**Interfaces:**
- `bin/jarvos-iso-release <vX.Y.Z> [--notes FILE]`: refuses dirty tree; asserts `configs/airootfs/usr/share/jarvos-iso/version` == `X.Y.Z` (else instructs to bump + commit); builds ISO if `release/jarvos-X.Y.Z-x86_64.iso` missing; `git tag -a vX.Y.Z -m "JarvOS ISO X.Y.Z"`; `git push origin main --tags`; `gh release create vX.Y.Z release/jarvos-X.Y.Z-x86_64.iso release/jarvos-X.Y.Z-x86_64.iso.sha256 --title "JarvOS ISO X.Y.Z" --notes-file NOTES` (default notes generated: what it installs, sha256, "tested: unattended core install in QEMU on <date>", known limits: online install / AUR build time).

- [ ] **Step 1**: write script; shellcheck.
- [ ] **Step 2**: `gh repo create pmatheus/jarvos-iso --public --source ~/jarvos-iso --remote origin --description "JarvOS installer ISO — the easiest way to install Arch with the AI-native JarvOS desktop (Omarchy-style)" --push`; enable Pages from `main` `/docs`: `gh api -X POST repos/pmatheus/jarvos-iso/pages -f 'source[branch]=main' -f 'source[path]=/docs'` (verify endpoint with `gh api --help`/docs; on 409 it already exists).
- [ ] **Step 3**: `bin/jarvos-iso-release v0.1.0`; verify `gh release view v0.1.0` lists both assets; `curl -sI https://pmatheus.github.io/jarvos-iso/ | head -1` → 200 (Pages can take a few minutes; poll up to 10 min).
- [ ] **Step 4**: JarvOS README — under "One-Line Install" add first: "**Fresh machine?** Download the JarvOS ISO: https://github.com/pmatheus/jarvos-iso/releases/latest — boot, answer the wizard, done." Commit `docs: point to jarvos-iso for fresh installs` and push.
- [ ] **Step 5**: Report: release URL, Pages URL, ISO size + sha256, test evidence from Task 8.

---

## Verification

Plan is complete when all are observably true:
1. `~/jarvos-iso/test/all` exits 0 (lint + 4 unit tests).
2. `release/jarvos-0.1.0-x86_64.iso` exists, < 2 GiB, `.sha256` matches.
3. `bin/jarvos-iso-test release/jarvos-0.1.0-x86_64.iso --profile core` printed PASS in this session (serial log shows `JARVOS_INSTALL_OK`; SSH assertions: sddm active, hyprland + quickshell installed, `~/.config/quickshell/jarvos/shell.qml` present, `/etc/jarvos-release` has `JARVOS_PROFILE=core`, `hypr-box` on PATH).
4. `gh release view v0.1.0 -R pmatheus/jarvos-iso` shows ISO + sha256 assets; `https://pmatheus.github.io/jarvos-iso/` returns 200.
5. `pmatheus/JarvOS` main contains Task 1 changes + README link; `pmatheus/jarvos-iso` README/CREDITS/site credit Omarchy, archiso, archinstall, Caelestia, END-4, chsoares/hypr-arch, chsoares/ctf.fish, chsoares/ezpz.
6. `full` profile: `yay -Sp --needed $(cat ~/JarvOS/system/packages/aur-security.txt aur-apps.txt)` dry-run resolves (document any AUR package that fails to resolve in the release notes) — not a VM install (declared limit).
