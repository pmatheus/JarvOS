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

start_test "GlobalProtect dispatches to the open-source CLI"
run_cmd jarvos-vpn connect work --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "gpclient" &&
    assert_stdout_contains "$RUN_OUT" "connect" &&
    assert_stdout_contains "$RUN_OUT" "vpn-work" &&
    pass_test

start_test "and SAML uses an isolated browser instead of the broken WebKit view"
assert_stdout_contains "$RUN_OUT" "--browser" &&
    assert_stdout_contains "$RUN_OUT" "jarvos-vpn-browser" &&
    pass_test

start_test "the isolated browser forces a fresh Entra session"
cat >"$FAKE_BIN/google-chrome-stable" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$FAKE_STATE/chrome-argv"
EOF
chmod +x "$FAKE_BIN/google-chrome-stable"
run_cmd jarvos-vpn-browser https://auth.example
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/chrome-argv" "--incognito" &&
    assert_contains "$FAKE_STATE/chrome-argv" "--new-window" &&
    assert_contains "$FAKE_STATE/chrome-argv" "https://auth.example" &&
    pass_test

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

# --- adding profiles -----------------------------------------------------

# secret-tool is shimmed to record how it was called. What matters is not that
# it stored something but HOW: a password on the command line is readable by
# every process on the machine via ps, so it must arrive on stdin.
cat >"$FAKE_BIN/secret-tool" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/secret-tool-argv"
case "${1-}" in
    store)  cat > "$FAKE_STATE/secret-tool-stdin" ;;
    lookup) cat "$FAKE_STATE/secret-tool-stored" 2>/dev/null || exit 1 ;;
    clear)  rm -f "$FAKE_STATE/secret-tool-stored" ;;
esac
EOF
chmod +x "$FAKE_BIN/secret-tool"
: >"$FAKE_STATE/secret-tool-argv"

printf '[]\n' >"$PROFILES"

start_test "add writes a profile"
run_cmd jarvos-vpn add --name mte --vendor panorama --server vpn.mte.example --auth sso
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$PROFILES" "mte" &&
    pass_test

start_test "and normalises the vendor people say into the one we dispatch on"
if grep -q '"vendor": *"globalprotect"' "$PROFILES"; then
    pass_test
else
    fail_test "panorama was not normalised: $(cat "$PROFILES")"
fi

start_test "adding the same name twice is refused, not silently merged"
run_cmd jarvos-vpn add --name mte --vendor fortinet --server other.example
assert_status "$RUN_STATUS" 1 && pass_test

start_test "add refuses a vendor we cannot dispatch"
run_cmd jarvos-vpn add --name x --vendor nortel --server x.example
assert_status "$RUN_STATUS" 1 && pass_test

start_test "add refuses to take a password as an argument"
# There is a --password flag people will reach for. It must not exist: an
# argument is visible in ps to every process on the box.
run_cmd jarvos-vpn add --name y --vendor fortinet --server y.example --password hunter2
assert_status "$RUN_STATUS" 1 &&
    { [[ "$RUN_OUT" != *hunter2* ]] || fail_test "the refusal echoed the password"; } &&
    pass_test

# --- passwords ------------------------------------------------------------

start_test "set-password reads the secret from stdin, never from argv"
run_cmd_stdin "correct-horse" jarvos-vpn set-password mte
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/secret-tool-stdin" "correct-horse" &&
    assert_not_contains "$FAKE_STATE/secret-tool-argv" "correct-horse" &&
    pass_test

start_test "the keyring entry is scoped to this app and this profile"
assert_contains "$FAKE_STATE/secret-tool-argv" "jarvos-vpn" &&
    assert_contains "$FAKE_STATE/secret-tool-argv" "mte" &&
    pass_test

# --- connect: SSO vs password --------------------------------------------

start_test "a GlobalProtect SSO profile uses the external browser callback"
run_cmd jarvos-vpn connect mte --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "gpclient" &&
    assert_stdout_contains "$RUN_OUT" "connect" &&
    assert_stdout_contains "$RUN_OUT" "jarvos-vpn-browser" &&
    { [[ "$RUN_OUT" != *passwd-on-stdin* ]] || fail_test "an SSO profile asked for a password"; } &&
    pass_test

start_test "a GlobalProtect profile pins its configured gateway"
jq 'map(if .name == "mte" then . + {"gateway": "primary.example"} else . end)' "$PROFILES" >"$PROFILES.tmp"
mv "$PROFILES.tmp" "$PROFILES"
run_cmd jarvos-vpn connect mte --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "--gateway primary.example" &&
    pass_test

start_test "a Fortinet SSO profile uses openconnect's external browser"
run_cmd jarvos-vpn add --name forti-sso --vendor fortinet --server fw.example --auth sso
run_cmd jarvos-vpn connect forti-sso --dry-run
assert_stdout_contains "$RUN_OUT" "--external-browser" && pass_test

start_test "a password profile feeds the secret on stdin, not on the command line"
run_cmd jarvos-vpn add --name pw --vendor fortinet --server pw.example --user bob --auth password
echo "s3cret" >"$FAKE_STATE/secret-tool-stored"
run_cmd jarvos-vpn connect pw --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "--passwd-on-stdin" &&
    { [[ "$RUN_OUT" != *s3cret* ]] || fail_test "the password reached the command line"; } &&
    pass_test

start_test "a password profile with nothing in the keyring says so before connecting"
rm -f "$FAKE_STATE/secret-tool-stored"
run_cmd jarvos-vpn connect pw --dry-run
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "set-password" &&
    pass_test

# --- removing -------------------------------------------------------------

start_test "remove drops the profile and its keyring entry together"
echo "s3cret" >"$FAKE_STATE/secret-tool-stored"
run_cmd jarvos-vpn remove pw
assert_status "$RUN_STATUS" 0 &&
    assert_not_contains "$PROFILES" '"pw"' &&
    assert_contains "$FAKE_STATE/secret-tool-argv" "clear" &&
    pass_test

# --- several tunnels at once ---------------------------------------------

start_test "every profile gets its own interface, named after it"
write_profiles <<'EOF'
[{"name": "mre-tci", "vendor": "fortinet", "server": "a.example", "auth": "sso"},
 {"name": "mte",     "vendor": "paloalto", "server": "b.example", "auth": "sso"}]
EOF
run_cmd jarvos-vpn connect mre-tci --dry-run
assert_stdout_contains "$RUN_OUT" "vpn-mre-tci" && pass_test

start_test "and the name is capped to what the kernel allows (15 chars)"
write_profiles <<'EOF'
[{"name": "a-very-long-profile-name", "vendor": "fortinet", "server": "x.example", "auth": "sso"}]
EOF
run_cmd jarvos-vpn connect a-very-long-profile-name --dry-run
iface="$(printf '%s' "$RUN_OUT" | grep -oE 'vpn-[A-Za-z0-9-]+' | head -1)"
if [[ -n "$iface" && "${#iface}" -le 15 ]]; then pass_test; else fail_test "interface '$iface' exceeds 15 chars"; fi

start_test "status lists every tunnel, each tagged with its profile"
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"vpn-mre-tci","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"172.17.66.4"}]},
 {"ifname":"vpn-mte","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"10.200.1.7"}]}]
EOF
run_cmd jarvos-vpn status --json
if printf '%s' "$RUN_OUT" | jq -e '.connected and (.tunnels|length==2) and (.tunnels[0].profile=="mre-tci") and (.tunnels[1].profile=="mte")' >/dev/null 2>&1; then
    pass_test
else
    fail_test "expected two tagged tunnels: $RUN_OUT"
fi

start_test "the GP Connect tun0 tunnel is tagged when one GlobalProtect profile exists"
write_profiles <<'EOF'
[{"name": "mte", "vendor": "globalprotect", "server": "vpn.example.com"}]
EOF
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"tun0","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"172.17.66.5"}]}]
EOF
run_cmd jarvos-vpn status --json
if printf '%s' "$RUN_OUT" | jq -e '.tunnels[0].profile == "mte"' >/dev/null 2>&1; then
    pass_test
else
    fail_test "expected tun0 to be tagged mte: $RUN_OUT"
fi

start_test "with two tunnels up, a bare disconnect refuses to guess"
write_profiles <<'EOF'
[{"name": "mre-tci", "vendor": "fortinet", "server": "a.example", "auth": "sso"},
 {"name": "mte",     "vendor": "paloalto", "server": "b.example", "auth": "sso"}]
EOF
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"vpn-mre-tci","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"172.17.66.4"}]},
 {"ifname":"vpn-mte","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"10.200.1.7"}]}]
EOF
run_cmd jarvos-vpn disconnect
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "mre-tci" &&
    assert_stdout_contains "$RUN_OUT" "mte" &&
    pass_test

start_test "disconnecting one names the interface so only that client is signalled"
cat >"$FAKE_BIN/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/pkill-argv"
EOF
chmod +x "$FAKE_BIN/pkill"
cat >"$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$FAKE_BIN/pgrep"
: >"$FAKE_STATE/pkill-argv"
write_profiles <<'EOF'
[{"name": "mre-tci", "vendor": "fortinet", "server": "a.example", "auth": "sso"},
 {"name": "mte",     "vendor": "paloalto", "server": "b.example", "auth": "sso"}]
EOF
run_cmd jarvos-vpn disconnect mre-tci
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pkill-argv" "vpn-mre-tci" &&
    assert_not_contains "$FAKE_STATE/pkill-argv" "vpn-mte" &&
    pass_test

start_test "disconnecting a GlobalProtect tunnel uses GP Connect only"
cat >"$FAKE_BIN/gpclient" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/gpclient-argv"
EOF
chmod +x "$FAKE_BIN/gpclient"
write_profiles <<'EOF'
[{"name": "mte", "vendor": "globalprotect", "server": "b.example", "auth": "sso"}]
EOF
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"tun0","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"10.200.1.7"}]}]
EOF
: >"$FAKE_STATE/gpclient-argv"
run_cmd jarvos-vpn disconnect mte
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/gpclient-argv" "disconnect" &&
    pass_test

start_test "with exactly one tunnel, a bare disconnect knows which"
write_profiles <<'EOF'
[{"name": "mte", "vendor": "fortinet", "server": "b.example", "auth": "sso"}]
EOF
cat >"$FAKE_STATE/ip-json" <<'EOF'
[{"ifname":"vpn-mte","linkinfo":{"info_kind":"tun"},"addr_info":[{"family":"inet","local":"10.200.1.7"}]}]
EOF
: >"$FAKE_STATE/pkill-argv"
run_cmd jarvos-vpn disconnect
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pkill-argv" "vpn-mte" &&
    pass_test
echo '[]' >"$FAKE_STATE/ip-json"

summary "jarvos-vpn"
