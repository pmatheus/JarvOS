#!/usr/bin/env bash
# jarvos-vpn — one client for every VPN vendor.
#
# The point of the wrapper is that a profile names a vendor and the wrapper
# knows which binary speaks that vendor's dialect: gpclient for GlobalProtect
# (because its SAML flow needs gpauth), openconnect for the five protocols it
# handles natively, snx-rs for Checkpoint. These tests pin that dispatch.
#
# Run: tests/jarvos-vpn.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

PROFILES="$FAKE_HOME/.config/jarvos/vpn/profiles.json"
mkdir -p "$(dirname "$PROFILES")"

write_profiles() {
    cat >"$PROFILES"
}

# `ip` is shimmed so a tunnel can be conjured without one existing.
cat >"$FAKE_BIN/ip" <<'EOF'
#!/usr/bin/env bash
cat "$FAKE_STATE/ip-json" 2>/dev/null || echo '[]'
EOF
chmod +x "$FAKE_BIN/ip"
echo '[]' >"$FAKE_STATE/ip-json"

# --- status --------------------------------------------------------------

start_test "with no tunnel, status reports disconnected and exits 1"
run_cmd jarvos-vpn status
assert_status "$RUN_STATUS" 1 && pass_test

start_test "status --json is valid JSON even when disconnected"
run_cmd jarvos-vpn status --json
if printf '%s' "$RUN_OUT" | jq -e '.connected == false' >/dev/null 2>&1; then
    pass_test
else
    fail_test "not valid JSON with connected:false: $RUN_OUT"
fi

start_test "a live tunnel is reported with its address"
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"tun0","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"172.17.66.4"}]}]
EOF
run_cmd jarvos-vpn status
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "172.17.66.4" &&
    pass_test

start_test "tailscale is never mistaken for a VPN tunnel"
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"tailscale0","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"100.94.79.9"}]}]
EOF
run_cmd jarvos-vpn status
assert_status "$RUN_STATUS" 1 && pass_test
echo '[]' >"$FAKE_STATE/ip-json"

# --- profiles ------------------------------------------------------------

start_test "with no profiles, list says so and does not error"
run_cmd jarvos-vpn list
assert_status "$RUN_STATUS" 0 && pass_test

start_test "list shows each profile with its vendor"
write_profiles <<'EOF'
[
  {"name": "work", "vendor": "globalprotect", "server": "vpn.example.com"},
  {"name": "client-a", "vendor": "fortinet", "server": "fw.example.net"}
]
EOF
run_cmd jarvos-vpn list
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "work" &&
    assert_stdout_contains "$RUN_OUT" "globalprotect" &&
    assert_stdout_contains "$RUN_OUT" "client-a" &&
    pass_test

start_test "list --json is machine readable, for the popout"
run_cmd jarvos-vpn list --json
if printf '%s' "$RUN_OUT" | jq -e 'length == 2' >/dev/null 2>&1; then
    pass_test
else
    fail_test "expected a 2-element array: $RUN_OUT"
fi

# --- vendor dispatch: the reason this wrapper exists ----------------------

start_test "GlobalProtect dispatches to gpclient, which owns the SAML flow"
run_cmd jarvos-vpn connect work --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "gpclient" &&
    assert_stdout_contains "$RUN_OUT" "vpn.example.com" &&
    pass_test

start_test "and it asks for an external browser, not the licensed GUI"
assert_stdout_contains "$RUN_OUT" "--browser" && pass_test

start_test "Fortinet dispatches to openconnect with its protocol"
run_cmd jarvos-vpn connect client-a --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "openconnect" &&
    assert_stdout_contains "$RUN_OUT" "--protocol=fortinet" &&
    pass_test

start_test "every openconnect protocol maps to itself"
write_profiles <<'EOF'
[
  {"name": "c", "vendor": "anyconnect", "server": "a.example.com"},
  {"name": "f", "vendor": "f5", "server": "b.example.com"},
  {"name": "p", "vendor": "pulse", "server": "c.example.com"},
  {"name": "j", "vendor": "juniper", "server": "d.example.com"},
  {"name": "a", "vendor": "array", "server": "e.example.com"}
]
EOF
ok=1
for pair in "c:anyconnect" "f:f5" "p:pulse" "j:nc" "a:array"; do
    run_cmd jarvos-vpn connect "${pair%%:*}" --dry-run
    [[ "$RUN_OUT" == *"--protocol=${pair##*:}"* ]] || { ok=0; break; }
done
if [[ "$ok" -eq 1 ]]; then
    pass_test
else
    fail_test "a protocol did not map: ${pair}"
fi

start_test "Checkpoint dispatches to snx-rs, which openconnect cannot do"
write_profiles <<'EOF'
[{"name": "cp", "vendor": "checkpoint", "server": "cp.example.com"}]
EOF
run_cmd jarvos-vpn connect cp --dry-run
assert_stdout_contains "$RUN_OUT" "snx" && pass_test

start_test "an unknown vendor is refused, naming what is supported"
write_profiles <<'EOF'
[{"name": "bad", "vendor": "nortel", "server": "x.example.com"}]
EOF
run_cmd jarvos-vpn connect bad --dry-run
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "fortinet" &&
    pass_test

start_test "an unknown profile is refused, naming the ones that exist"
run_cmd jarvos-vpn connect definitely-not-a-profile --dry-run
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "bad" &&
    pass_test

# --- secrets -------------------------------------------------------------

start_test "a password in a profile is refused rather than used"
# Profiles are config, not a vault. GlobalProtect authenticates through SSO and
# openconnect prompts, so nothing here ever needs a stored password — and a file
# that accepts one becomes the place people put them.
write_profiles <<'EOF'
[{"name": "leaky", "vendor": "fortinet", "server": "x.example.com", "password": "hunter2"}]
EOF
run_cmd jarvos-vpn connect leaky --dry-run
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "password" &&
    pass_test

start_test "and the refusal does not echo the value back"
if [[ "$RUN_OUT" != *hunter2* ]]; then
    pass_test
else
    fail_test "the refusal printed the secret"
fi

# --- argument handling ---------------------------------------------------

start_test "connect with no profile is refused"
run_cmd jarvos-vpn connect
assert_status "$RUN_STATUS" 1 && pass_test

start_test "an unknown subcommand is refused"
run_cmd jarvos-vpn frobnicate
assert_status "$RUN_STATUS" 1 && pass_test

start_test "malformed profile JSON is a readable error, not a crash"
printf 'not json at all\n' >"$PROFILES"
run_cmd jarvos-vpn list
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "profiles" &&
    pass_test

summary "jarvos-vpn"
