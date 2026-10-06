#!/usr/bin/env bash
# Finding and restarting what still runs code an update replaced.
# Run: tests/jarvos-update-stale.test.sh
#
# Stub bodies are single-quoted on purpose: $FAKE_STATE must reach the file
# unexpanded so the stub expands it when it runs.
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

PROC="$SANDBOX_ROOT/proc"
export JARVOS_PROC="$PROC"

# fake_process <pid> <comm> <cgroup-path> <map-line>...
fake_process() {
    local pid="$1" comm="$2" cgroup="$3"
    shift 3
    mkdir -p "$PROC/$pid"
    printf '%s\n' "$comm" >"$PROC/$pid/comm"
    printf '0::%s\n' "$cgroup" >"$PROC/$pid/cgroup"
    printf '%s\n' "$@" >"$PROC/$pid/maps"
    ln -sfn "/usr/bin/$comm" "$PROC/$pid/exe"
}

map() { printf '7f00-7f01 r-xp 00000000 00:1f 123 %s' "$1"; }

make_world() {
    rm -rf "$PROC"
    fake_process 1 systemd /init.scope "$(map '/usr/lib/libc.so.6 (deleted)')"
    fake_process 101 sshd /system.slice/sshd.service "$(map '/usr/lib/libssl.so.3 (deleted)')"
    fake_process 102 firefox /user.slice/user-1000.slice/user@1000.service/app.slice/app-firefox@1.service \
        "$(map '/usr/lib/libnss3.so (deleted)')"
    fake_process 103 bash /user.slice/user-1000.slice/session-2.scope "$(map /usr/lib/libc.so.6)"
    fake_process 104 kitty /user.slice/user-1000.slice/session-2.scope "$(map '/memfd:wayland-shm (deleted)')"
    fake_process 105 sliver-server /system.slice/sliver.service "$(map '/usr/lib/libz.so.1 (deleted)')"
    fake_process 106 dbus-broker /system.slice/dbus-broker.service "$(map '/usr/lib/libsystemd.so.0 (deleted)')"
    fake_process 107 tailscaled /system.slice/tailscaled.service "$(map '/usr/lib/libc.so.6 (deleted)')"
    # The binary itself replaced, with no library involved.
    fake_process 108 cupsd /system.slice/cups.service "$(map /usr/lib/libc.so.6)"
    ln -sfn '/usr/bin/cupsd (deleted)' "$PROC/108/exe"
    fake_process 110 mount.ntfs-3g /system.slice/home-user-hd10tb.mount \
        "$(map '/usr/lib/libntfs-3g.so.89 (deleted)')"
    fake_process 111 smbd /system.slice/smb.service "$(map '/usr/lib/libc.so.6 (deleted)')"
    fake_process 109 Hyprland /user.slice/user-1000.slice/session-2.scope "$(map '/usr/lib/libhyprutils.so.9 (deleted)')"
}

# --- jarvos-update-stale -------------------------------------------------

make_world
start_test "replaced libraries and binaries are found, with who owns them"
run_cmd jarvos-update-stale
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" $'system\tsshd.service\t101\tsshd' &&
    assert_stdout_contains "$RUN_OUT" $'user\tapp-firefox@1.service\t102\tfirefox' &&
    assert_stdout_contains "$RUN_OUT" $'system\tcups.service\t108\tcupsd' &&
    assert_stdout_contains "$RUN_OUT" $'session\tsession-2.scope\t109\tHyprland' &&
    assert_stdout_contains "$RUN_OUT" $'init\tinit.scope\t1\tsystemd' &&
    assert_stdout_contains "$RUN_OUT" $'system\thome-user-hd10tb.mount\t110\tmount.ntfs-3g' &&
    pass_test

start_test "a process running only current code is not listed"
{ [[ "$RUN_OUT" != *$'\t103\t'* ]] || fail_test "listed the up-to-date bash"; } && pass_test

start_test "a deleted shared-memory file is not mistaken for old code"
{ [[ "$RUN_OUT" != *$'\t104\t'* ]] || fail_test "listed kitty over a memfd"; } && pass_test

# --- jarvos-update-restart-stale -----------------------------------------

# A systemctl that knows where each unit file lives (packaged under
# /usr/lib, written locally under /etc) and records what it is asked to do.
cat >"$FAKE_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    show)       unit="${2}"
                if [[ "$unit" == sliver.service ]]; then echo /etc/systemd/system/sliver.service
                else echo "/usr/lib/systemd/system/$unit"; fi ;;
    try-restart) printf 'restart %s\n' "$2" >> "$FAKE_STATE/systemctl-calls"
                [[ -e "$FAKE_STATE/restart-fails-$2" ]] && exit 1
                exit 0 ;;
    daemon-reexec) printf 'reexec\n' >> "$FAKE_STATE/systemctl-calls" ;;
esac
EOF
chmod +x "$FAKE_BIN/systemctl"

make_world
: >"$FAKE_STATE/systemctl-calls"
start_test "packaged services running old code are restarted"
run_cmd jarvos-update-restart-stale
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/systemctl-calls" "restart sshd.service" &&
    assert_contains "$FAKE_STATE/systemctl-calls" "restart cups.service" &&
    pass_test

start_test "systemd itself is re-executed rather than restarted"
assert_contains "$FAKE_STATE/systemctl-calls" "reexec" && pass_test

start_test "nothing that would end the session or cut the network is restarted"
assert_not_contains "$FAKE_STATE/systemctl-calls" "dbus-broker" &&
    assert_not_contains "$FAKE_STATE/systemctl-calls" "tailscaled" &&
    pass_test

start_test "a FUSE mount running old code is never restarted, which would unmount it"
assert_not_contains "$FAKE_STATE/systemctl-calls" "hd10tb" && pass_test

start_test "a file server is not restarted under a transfer"
assert_not_contains "$FAKE_STATE/systemctl-calls" "smb.service" && pass_test

start_test "the user's own services are reported, never restarted"
assert_not_contains "$FAKE_STATE/systemctl-calls" "sliver" &&
    assert_stdout_contains "$RUN_OUT" "sliver.service" &&
    pass_test

start_test "the desktop and its apps are left alone"
assert_not_contains "$FAKE_STATE/systemctl-calls" "firefox" &&
    assert_not_contains "$FAKE_STATE/systemctl-calls" "session-2" &&
    pass_test

make_world
: >"$FAKE_STATE/systemctl-calls"
: >"$FAKE_STATE/restart-fails-sshd.service"
start_test "a restart that fails is reported and the others still happen"
run_cmd jarvos-update-restart-stale
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "sshd.service" &&
    assert_contains "$FAKE_STATE/systemctl-calls" "restart cups.service" &&
    pass_test
rm -f "$FAKE_STATE/restart-fails-sshd.service"

summary "jarvos-update-stale"
