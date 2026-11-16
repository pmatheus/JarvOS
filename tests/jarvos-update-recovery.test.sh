#!/usr/bin/env bash
# The update's self-repair: rule-based conflict resolution, the health gate,
# the live rollback and the AI resolver, each alone.
# Run: tests/jarvos-update-recovery.test.sh
#
# Stub bodies below are single-quoted on purpose: $FAKE_STATE must reach the
# file unexpanded so the stub expands it when it runs.
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_PACMAN_LOCK="$SANDBOX_ROOT/db.lck"

# A pacman driven by a script per subcommand: each call pops one line,
# "<exit>|<message>", from $FAKE_STATE/pacman-script<first-arg>. No script
# means success. Every call is recorded, arguments and all.
cat >"$FAKE_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
key="$1"
printf '%s\n' "$*" >> "$FAKE_STATE/pacman-calls$key"
case "$key" in
    -Qo) grep -qxF "$2" "$FAKE_STATE/owned-files" 2>/dev/null ;;
    -Qq) cat "$FAKE_STATE/pacman-explicit" ;;
    -Q)  cat "$FAKE_STATE/pacman-q" 2>/dev/null ;;
    *)   f="$FAKE_STATE/pacman-script$key"
         if [[ -s "$f" ]]; then
             line="$(head -1 "$f")"; sed -i 1d "$f"
             msg="${line#*|}"; [[ -n "$msg" ]] && printf '%b\n' "$msg"
             exit "${line%%|*}"
         fi
         exit 0 ;;
esac
EOF
cat >"$FAKE_BIN/pacman-key" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/pacman-key-calls"
EOF
chmod +x "$FAKE_BIN/pacman" "$FAKE_BIN/pacman-key"

pacman_script() {
    # pacman_script <subcommand> <line>...
    local key="$1"
    shift
    printf '%s\n' "$@" >"$FAKE_STATE/pacman-script$key"
}

reset_pacman() {
    rm -f "$FAKE_STATE"/pacman-script* "$FAKE_STATE"/pacman-calls* \
        "$FAKE_STATE/pacman-key-calls" "$FAKE_STATE/owned-files" "$JARVOS_PACMAN_LOCK"
}

calls() { wc -l <"$FAKE_STATE/pacman-calls$1" 2>/dev/null || echo 0; }

# --- jarvos-update-system-pkgs: the rules -------------------------------

reset_pacman
start_test "conflicting packages are resolved by flipping only that default"
pacman_script -Syu \
    "1|:: foo and bar are in conflict. Remove bar? [y/N]\nerror: unresolvable package conflicts detected" \
    "0|"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(calls -Syu)" -eq 2 ]] || fail_test "expected 2 attempts, got $(calls -Syu)"; } &&
    { [[ "$(tail -1 "$FAKE_STATE/pacman-calls-Syu")" == *"--ask=4"* ]] ||
        fail_test "retry lacked --ask=4: $(tail -1 "$FAKE_STATE/pacman-calls-Syu")"; } &&
    pass_test

reset_pacman
start_test "an unowned file in the way is overwritten, by exact path only"
pacman_script -Syu \
    "1|error: failed to commit transaction (conflicting files)\nfoo: /usr/lib/libfoo.so exists in filesystem\nErrors occurred, no packages were upgraded." \
    "0|"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-calls-Syu" "--overwrite /usr/lib/libfoo.so" &&
    assert_not_contains "$FAKE_STATE/pacman-calls-Syu" "--overwrite *" &&
    pass_test

reset_pacman
start_test "a file another package owns is never overwritten"
printf '/usr/lib/libbar.so\n' >"$FAKE_STATE/owned-files"
pacman_script -Syu \
    "1|error: failed to commit transaction (conflicting files)\nfoo: /usr/lib/libbar.so exists in filesystem (owned by bar)" \
    "0|"
run_cmd jarvos-update-system-pkgs
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_not_contains "$FAKE_STATE/pacman-calls-Syu" "--overwrite" &&
    pass_test

reset_pacman
start_test "a stale lock is removed and the transaction retried"
# "Stale" means no package manager is running. Ask a stub, not the real
# process table: a real pacman elsewhere on the box (an ISO build) made the
# lock look held and this test fail.
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_BIN/pgrep"
chmod +x "$FAKE_BIN/pgrep"
: >"$JARVOS_PACMAN_LOCK"
pacman_script -Syu "1|error: failed to init transaction (unable to lock database)" "0|"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$JARVOS_PACMAN_LOCK" &&
    pass_test
rm -f "$FAKE_BIN/pgrep"

reset_pacman
start_test "a bad signature repopulates the keyring and drops the corrupt download"
corrupt="$SANDBOX_ROOT/foo-1.0-1-x86_64.pkg.tar.zst"
: >"$corrupt"
pacman_script -Syu \
    "1|error: foo: signature from \"Someone\" is unknown trust\n:: File $corrupt is corrupted (invalid or corrupted package (PGP signature))." \
    "0|"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-key-calls" "--populate" &&
    assert_no_file "$corrupt" &&
    pass_test

reset_pacman
start_test "a network failure exits 75, which no repair is called for"
pacman_script -Syu "1|error: failed retrieving file 'core.db' from mirror : Could not resolve host: mirror"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 75 && pass_test

reset_pacman
start_test "an unknown failure is not guessed at: one attempt, non-zero"
pacman_script -Syu "1|error: something nobody has seen before" "0|"
run_cmd jarvos-update-system-pkgs
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    { [[ "$(calls -Syu)" -eq 1 ]] || fail_test "retried $(calls -Syu) times"; } &&
    pass_test

reset_pacman
start_test "the same rule is not applied twice"
pacman_script -Syu \
    "1|:: a and b are in conflict. Remove b? [y/N]" \
    "1|:: a and b are in conflict. Remove b? [y/N]" \
    "0|"
run_cmd jarvos-update-system-pkgs
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    { [[ "$(calls -Syu)" -eq 2 ]] || fail_test "ran $(calls -Syu) times"; } &&
    pass_test

# --- jarvos-update-keyring -----------------------------------------------

reset_pacman
start_test "a keyring that will not refresh is repopulated and retried"
pacman_script -Sy "1|error: archlinux-keyring: signature is invalid" "0|"
run_cmd jarvos-update-keyring
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-key-calls" "--populate" &&
    { [[ "$(calls -Sy)" -eq 2 ]] || fail_test "expected 2 attempts, got $(calls -Sy)"; } &&
    pass_test

reset_pacman
start_test "a keyring refresh that fails on the network exits 75"
pacman_script -Sy "1|error: failed to synchronize all databases (unexpected error)\nCould not resolve host: x"
run_cmd jarvos-update-keyring
assert_status "$RUN_STATUS" 75 && pass_test

# --- jarvos-update-health ------------------------------------------------

SYSROOT="$SANDBOX_ROOT/sysroot"
export JARVOS_SYSROOT="$SYSROOT"

healthy_sysroot() {
    rm -rf "$SYSROOT"
    mkdir -p "$SYSROOT/boot" "$SYSROOT/usr/lib/modules/7.2.6-arch2-1/updates/dkms" \
        "$SYSROOT/usr/lib/modules/6.19.10-arch1-1"
    printf 'linux\n' >"$SYSROOT/usr/lib/modules/7.2.6-arch2-1/pkgbase"
    printf 'dep\n' >"$SYSROOT/usr/lib/modules/7.2.6-arch2-1/modules.dep"
    printf 'ko\n' >"$SYSROOT/usr/lib/modules/7.2.6-arch2-1/updates/dkms/nvidia.ko.zst"
    printf 'k\n' >"$SYSROOT/boot/vmlinuz-linux"
    printf 'i\n' >"$SYSROOT/boot/initramfs-linux.img"
    # A leftover from a removed kernel: a pkgbase nothing owns any more.
    printf 'linux\n' >"$SYSROOT/usr/lib/modules/6.19.10-arch1-1/pkgbase"
    printf '/usr/lib/modules/7.2.6-arch2-1/pkgbase\n' >"$FAKE_STATE/owned-files"
    printf 'base\nlinux\nmkinitcpio\nnvidia-open-dkms\n' >"$FAKE_STATE/pacman-explicit"
}

reset_pacman
healthy_sysroot
start_test "a bootable system passes, ignoring a removed kernel's leftovers"
run_cmd jarvos-update-health
assert_status "$RUN_STATUS" 0 && pass_test

reset_pacman
healthy_sysroot
start_test "a missing initramfs fails the gate"
rm "$SYSROOT/boot/initramfs-linux.img"
run_cmd jarvos-update-health
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "initramfs-linux.img" &&
    pass_test

reset_pacman
healthy_sysroot
start_test "a kernel the NVIDIA module was not built for fails the gate"
rm "$SYSROOT/usr/lib/modules/7.2.6-arch2-1/updates/dkms/nvidia.ko.zst"
run_cmd jarvos-update-health
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "nvidia" &&
    pass_test

reset_pacman
healthy_sysroot
start_test "an inconsistent package database fails the gate"
pacman_script -Dk "1|error: missing 'glibc' dependency for 'bash'"
run_cmd jarvos-update-health
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "glibc" &&
    pass_test

reset_pacman
healthy_sysroot
start_test "no installed kernel at all fails the gate"
: >"$FAKE_STATE/owned-files"
run_cmd jarvos-update-health
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } && pass_test

# --- jarvos-update-rollback ----------------------------------------------

SNAPS="$SANDBOX_ROOT/snapshots"
export JARVOS_SNAPSHOTS="$SNAPS"
RUN_DIR="$SANDBOX_ROOT/run"
export JARVOS_UPDATE_RUN_DIR="$RUN_DIR"

# A system mid-way through a bad update, beside snapshot 42 of it before:
#   /usr/lib/libc.so    changed by the update       → content restored
#   /usr/lib/new.so     created by the update       → removed
#   /usr/lib/gone.so    deleted by the update       → restored
#   /usr/share/newdir/  created, with a file inside → both removed
#   /home/u/notes.txt   written during the update   → NEVER touched
make_rollback_world() {
    rm -rf "$SYSROOT" "$SNAPS" "$RUN_DIR"
    local snap="$SNAPS/42/snapshot"
    mkdir -p "$snap/usr/lib" "$snap/home/u" "$SYSROOT/usr/lib" "$SYSROOT/usr/share/newdir" \
        "$SYSROOT/home/u" "$RUN_DIR"
    printf 'old libc\n' >"$snap/usr/lib/libc.so"
    printf 'gone\n' >"$snap/usr/lib/gone.so"
    printf 'old notes\n' >"$snap/home/u/notes.txt"
    printf 'new libc\n' >"$SYSROOT/usr/lib/libc.so"
    printf 'new\n' >"$SYSROOT/usr/lib/new.so"
    printf 'x\n' >"$SYSROOT/usr/share/newdir/file"
    printf 'new notes\n' >"$SYSROOT/home/u/notes.txt"
    printf 'glibc 2.40-1\n' >"$RUN_DIR/packages-before"
    printf 'glibc 2.40-1\n' >"$FAKE_STATE/pacman-q"
    cat >"$FAKE_BIN/snapper" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/snapper-calls"
case "$*" in
    *status*) printf '%s\n' \
        'c..... /usr/lib/libc.so' \
        '+..... /usr/lib/new.so' \
        '-..... /usr/lib/gone.so' \
        '+..... /usr/share/newdir' \
        '+..... /usr/share/newdir/file' \
        'c..... /home/u/notes.txt' ;;
    *create*) echo 43 ;;
esac
EOF
    chmod +x "$FAKE_BIN/snapper"
}

reset_pacman
make_rollback_world
start_test "rollback restores what the update changed under the system paths"
run_cmd jarvos-update-rollback 42
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$SYSROOT/usr/lib/libc.so" "old libc" &&
    assert_file_exists "$SYSROOT/usr/lib/gone.so" &&
    assert_no_file "$SYSROOT/usr/lib/new.so" &&
    assert_no_file "$SYSROOT/usr/share/newdir" &&
    pass_test

start_test "rollback never touches /home, which the snapshot also covers"
assert_contains "$SYSROOT/home/u/notes.txt" "new notes" && pass_test

start_test "rollback compares against the live system, not a snapshot of it"
assert_contains "$FAKE_STATE/snapper-calls" "status 42..0" && pass_test

reset_pacman
make_rollback_world
start_test "a rollback whose package list does not match is reported as failed"
printf 'glibc 2.41-1\n' >"$FAKE_STATE/pacman-q"
run_cmd jarvos-update-rollback 42
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "glibc" &&
    pass_test

reset_pacman
start_test "rollback without a snapshot number refuses"
run_cmd jarvos-update-rollback
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } && pass_test

# --- jarvos-update-resolve -----------------------------------------------

export JARVOS_RESOLVER="$FAKE_BIN/fake-claude"
TRANSCRIPT_FILE="$SANDBOX_ROOT/transcript.log"
printf 'error: something nobody has seen before\n' >"$TRANSCRIPT_FILE"

fake_resolver() {
    # fake_resolver <final-line>
    cat >"$FAKE_BIN/fake-claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "\$FAKE_STATE/resolver-args"
env > "\$FAKE_STATE/resolver-env"
echo "looked at it"
echo "$1"
EOF
    chmod +x "$FAKE_BIN/fake-claude"
    rm -f "$FAKE_STATE/resolver-args"
}

fake_resolver JARVOS-RESOLVED
start_test "a resolved failure is worth retrying"
run_cmd jarvos-update-resolve jarvos-update-system-pkgs "$TRANSCRIPT_FILE"
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/resolver-args" "jarvos-update-system-pkgs" &&
    assert_contains "$FAKE_STATE/resolver-args" "something nobody has seen before" &&
    pass_test

start_test "the agent runs headless, with a budget, and cannot re-enter the update"
assert_contains "$FAKE_STATE/resolver-args" "-p" &&
    assert_contains "$FAKE_STATE/resolver-args" "--max-budget-usd" &&
    assert_contains "$FAKE_STATE/resolver-env" "JARVOS_UPDATE_RESOLVING=1" &&
    pass_test

start_test "the agent is told what it must never do"
assert_contains "$FAKE_STATE/resolver-args" "/home" &&
    assert_contains "$FAKE_STATE/resolver-args" "--overwrite" &&
    assert_contains "$FAKE_STATE/resolver-args" "snapshot" &&
    pass_test

fake_resolver JARVOS-UNRESOLVED
start_test "an unresolved failure is not retried"
run_cmd jarvos-update-resolve jarvos-update-system-pkgs "$TRANSCRIPT_FILE"
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } && pass_test

fake_resolver "no verdict line at all"
start_test "an agent that gives no verdict counts as unresolved"
run_cmd jarvos-update-resolve jarvos-update-system-pkgs "$TRANSCRIPT_FILE"
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } && pass_test

fake_resolver JARVOS-RESOLVED
start_test "JARVOS_UPDATE_NO_RESOLVE keeps the agent out entirely"
JARVOS_UPDATE_NO_RESOLVE=1 run_cmd jarvos-update-resolve jarvos-update-system-pkgs "$TRANSCRIPT_FILE"
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_no_file "$FAKE_STATE/resolver-args" &&
    pass_test

start_test "no agent installed is a plain failure, not a crash"
JARVOS_RESOLVER=/nonexistent/claude run_cmd jarvos-update-resolve jarvos-update-system-pkgs "$TRANSCRIPT_FILE"
assert_status "$RUN_STATUS" 1 && pass_test

# --- jarvos-update-devtools ----------------------------------------------

# A Flutter SDK is a git checkout, and `flutter upgrade` refuses to run over
# local edits (usually a pubspec.lock its own tooling rewrote). The fake
# refuses exactly the way the real one does, until the tree is clean.
SDK="$SANDBOX_ROOT/flutter"
make_flutter_sdk() {
    rm -rf "$SDK"
    mkdir -p "$SDK/bin"
    git -C "$SDK" init -q
    printf 'lock: 1\n' >"$SDK/pubspec.lock"
    git -C "$SDK" add pubspec.lock
    git -C "$SDK" -c user.name=t -c user.email=t@t commit -q -m sdk
    cat >"$SDK/bin/flutter" <<'EOF'
#!/usr/bin/env bash
sdk="$(dirname "$(dirname "$(readlink -f "$0")")")"
if [[ -n "$(git -C "$sdk" status --porcelain --untracked-files=no)" ]]; then
    echo 'Your flutter checkout has local changes that would be erased by upgrading.'
    exit 1
fi
echo upgraded >> "$FAKE_STATE/flutter-upgraded"
EOF
    chmod +x "$SDK/bin/flutter"
    ln -sfn "$SDK/bin/flutter" "$FAKE_BIN/flutter"
}

make_flutter_sdk
start_test "a Flutter upgrade blocked by local edits stashes them and goes through"
printf 'lock: 2\n' >"$SDK/pubspec.lock"
rm -f "$FAKE_STATE/flutter-upgraded"
JARVOS_DEVTOOLS_ONLY=flutter run_cmd jarvos-update-devtools
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$FAKE_STATE/flutter-upgraded" &&
    { git -C "$SDK" stash show -p 2>/dev/null | grep -q '^+lock: 2' || fail_test "edit not kept in the stash"; } &&
    pass_test

make_flutter_sdk
start_test "a clean Flutter checkout upgrades without touching the stash"
rm -f "$FAKE_STATE/flutter-upgraded"
JARVOS_DEVTOOLS_ONLY=flutter run_cmd jarvos-update-devtools
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$FAKE_STATE/flutter-upgraded" &&
    { [[ -z "$(git -C "$SDK" stash list)" ]] || fail_test "stashed with nothing to stash"; } &&
    pass_test

summary "jarvos-update-recovery"
