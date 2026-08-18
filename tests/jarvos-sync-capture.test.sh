#!/usr/bin/env bash
# jarvos-sync — capture behaviour: the delta, and everything it must refuse
# to touch. Run: tests/jarvos-sync-capture.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

STAGE=""

seed_home() {
    # identical to baseline -> must not be captured
    home_file .config/hypr/hyprland/general.conf <<<'gaps_in = 5'
    # changed vs baseline -> captured
    home_file .config/fish/config.fish <<<'set -g fish_greeting "hello"'
    # new file under an allow-listed dir -> captured
    home_file .config/fish/functions/gs.fish <<<'function gs; git status; end'
    # host-specific -> never captured
    home_file .config/hypr/hyprland/monitors.conf <<<'monitor=DP-1,3440x1440@144,0x0,1'
    home_file .config/hypr/hyprland/colors.conf <<<'$primary = rgb(ff0000)'
    home_file .config/hypr/hyprland/scheme/current.conf <<<'scheme = dynamic'
    # Secret-shaped -> never captured. The values are assembled at runtime by
    # the fake_* helpers in lib/sandbox.sh, so the tool is fed the real shapes
    # while this file carries no secret-shaped literal of its own.
    printf 'OPENAI_API_KEY=%s\n' "$(fake_openai_key)" | home_file .config/fish/conf.d/keys.env
    printf '{"token":"%s"}\n' "$(fake_github_token)" | home_file .claude/.credentials.json
    home_file .claude/history.jsonl <<<'{"prompt":"my private prompt"}'
    printf 'AWS_KEY=%s\n' "$(fake_aws_key)" | home_file .secrets/.env.central
    fake_private_key | home_file .ssh/id_ed25519
    home_file .bash_history <<<'sudo rm -rf /'
    home_file .claude/.current_system.json <<<'{"hostname":"thisbox"}'
    # portable claude assets -> captured (the chairman's ".claude and fly")
    home_file .claude/CLAUDE.md <<<'# Identity'
    home_file .claude/skills/demo/SKILL.md <<<'---
name: demo
---'
    # outside the allow-list -> never captured
    home_file Documents/taxes.txt <<<'personal'
    home_file .mozilla/profile/prefs.js <<<'user_pref("a", 1);'
    # references a secret by name only -> should surface in secrets.manifest,
    # while ordinary shouty variables next to it must not
    home_file .config/fish/conf.d/env.fish <<<'set -gx GITHUB_TOKEN $GITHUB_TOKEN
test $KEYWORD -a $PASSED -a $EDITOR -a $OPS_API_URL'
    # extra packages and units beyond the baseline
    printf 'base\nlinux\nhyprland\nkitty\nfish\nquickshell-git\nmatugen-bin\nbrave-bin\nlegacy-only-pkg\nneovim\nferoxbuster\nbinaryninja-free\n' \
        >"$FAKE_STATE/pacman-explicit"
    printf 'quickshell-git\nmatugen-bin\nbrave-bin\nlegacy-only-pkg\nferoxbuster\nbinaryninja-free\n' \
        >"$FAKE_STATE/pacman-foreign"
    printf 'NetworkManager.service\ndocker.service\ntailscaled.service\n' >"$FAKE_STATE/units-system"
    printf 'pipewire.socket\nclawmem-watcher.service\n' >"$FAKE_STATE/units-user"
}

capture_once() {
    STAGE="$SANDBOX_ROOT/stage"
    run_sync capture --into "$STAGE"
}

# --- tests --------------------------------------------------------------

test_help_lists_subcommands() {
    start_test "--help lists init/push/status/restore"
    run_sync --help
    assert_status "$RUN_STATUS" 0 || return
    for sub in init push status restore; do
        assert_stdout_contains "$RUN_OUT" "jarvos-sync $sub" || return
    done
    pass_test
}

test_identical_file_not_captured() {
    start_test "dotfile identical to the baseline is not captured"
    assert_no_file "$STAGE/dotfiles/.config/hypr/hyprland/general.conf" || return
    pass_test
}

test_changed_file_captured() {
    start_test "dotfile that differs from the baseline is captured with its content"
    assert_file_exists "$STAGE/dotfiles/.config/fish/config.fish" || return
    assert_contains "$STAGE/dotfiles/.config/fish/config.fish" 'hello' || return
    pass_test
}

test_new_file_captured() {
    start_test "file the distro does not ship is captured"
    assert_file_exists "$STAGE/dotfiles/.config/fish/functions/gs.fish" || return
    pass_test
}

test_host_specific_never_captured() {
    start_test "host-specific state (monitors/colors/scheme) is never captured"
    assert_no_file "$STAGE/dotfiles/.config/hypr/hyprland/monitors.conf" || return
    assert_no_file "$STAGE/dotfiles/.config/hypr/hyprland/colors.conf" || return
    assert_no_file "$STAGE/dotfiles/.config/hypr/hyprland/scheme" || return
    assert_no_file "$STAGE/dotfiles/.claude/.current_system.json" || return
    pass_test
}

test_secrets_never_captured() {
    start_test "secret-shaped paths are never captured"
    local p
    for p in .config/fish/conf.d/keys.env .claude/.credentials.json .claude/history.jsonl \
        .secrets/.env.central .ssh/id_ed25519 .bash_history; do
        assert_no_file "$STAGE/dotfiles/$p" || return
    done
    pass_test
}

test_out_of_scope_never_captured() {
    start_test "paths outside the allow-list are never captured"
    assert_no_file "$STAGE/dotfiles/Documents/taxes.txt" || return
    assert_no_file "$STAGE/dotfiles/.mozilla" || return
    pass_test
}

test_claude_assets_captured() {
    start_test "portable ~/.claude assets are captured"
    assert_file_exists "$STAGE/dotfiles/.claude/CLAUDE.md" || return
    assert_file_exists "$STAGE/dotfiles/.claude/skills/demo/SKILL.md" || return
    pass_test
}

test_staged_tree_has_no_secret_strings() {
    start_test "staged tree contains no secret-shaped string (content gate)"
    assert_no_secret_shaped_content "$STAGE" || return
    pass_test
}

test_packages_delta() {
    start_test "packages/explicit.txt is explicit minus the JarvOS baseline"
    assert_file_exists "$STAGE/packages/explicit.txt" || return
    assert_contains "$STAGE/packages/explicit.txt" 'neovim' || return
    assert_not_contains "$STAGE/packages/explicit.txt" 'hyprland' || return
    assert_not_contains "$STAGE/packages/explicit.txt" 'quickshell-git' || return
    pass_test
}

test_module_packages_are_baseline() {
    start_test "a package a module installs is baseline, not delta"
    assert_not_contains "$STAGE/packages/explicit.txt" 'brave-bin' || return
    pass_test
}

test_legacy_tier_only_package_is_delta() {
    start_test "a package only the retired v0.1 tiers listed still lands in the delta"
    assert_contains "$STAGE/packages/explicit.txt" 'legacy-only-pkg' || return
    pass_test
}

test_aur_delta() {
    start_test "packages/aur.txt holds only foreign packages outside the baseline"
    assert_file_exists "$STAGE/packages/aur.txt" || return
    assert_contains "$STAGE/packages/aur.txt" 'feroxbuster' || return
    assert_not_contains "$STAGE/packages/aur.txt" 'matugen-bin' || return
    assert_not_contains "$STAGE/packages/aur.txt" 'neovim' || return
    pass_test
}

test_uv_tools_delta() {
    start_test "uv tools the modules do not install are captured; the ones they do are not"
    assert_file_exists "$STAGE/packages/uv-tools.txt" || return
    assert_contains "$STAGE/packages/uv-tools.txt" 'user-tool' || return
    assert_contains "$STAGE/packages/uv-tools.txt" 'flaky-tool' || return
    assert_not_contains "$STAGE/packages/uv-tools.txt" 'demo-tool' || return
    pass_test
}

test_uv_tool_from_a_continued_loop_is_baseline() {
    start_test "a uv tool named on a continued [post] loop line is not captured"
    assert_not_contains "$STAGE/packages/uv-tools.txt" 'looped-tool' || return
    pass_test
}

test_uv_tool_installed_by_path_is_baseline() {
    start_test "a uv tool a module installs from a local checkout is not captured"
    assert_not_contains "$STAGE/packages/uv-tools.txt" 'hypr-box' || return
    pass_test
}

test_uv_tool_sharing_a_package_name_is_captured() {
    start_test "a uv tool whose name is only a module *package* still travels"
    # The catalogue's pacman package is not the uv tool of the same name, so
    # nothing in any [post] installs it — dropping it would lose it silently.
    assert_contains "$STAGE/packages/uv-tools.txt" 'sshuttle' || return
    pass_test
}

test_uv_tool_only_mentioned_by_a_post_block_is_captured() {
    start_test "a uv tool a [post] block only mentions, never installs, is captured"
    # dev.module's [post] says `usermod -aG docker,libvirt` and nothing else
    # about docker. Reading it as "the catalogue provides the docker uv tool"
    # loses the user's tool without a word — the failure this feature exists
    # to prevent — so the baseline is what [post] *installs*, not what it says.
    assert_contains "$STAGE/packages/uv-tools.txt" 'docker' || return
    pass_test
}

test_uv_executables_are_not_tools() {
    start_test "executables listed under a uv tool are not captured as tools"
    assert_not_contains "$STAGE/packages/uv-tools.txt" 'phantom-tool' || return
    pass_test
}

test_uv_tools_file_written_when_nothing_to_carry() {
    start_test "uv-tools.txt is written even when there is no uv tool to carry"
    # status diffs a fresh capture against the profile: a file that exists on
    # one machine and not on another is drift the user cannot act on.
    cp "$FAKE_STATE/uv-tools" "$SANDBOX_ROOT/uv-tools.bak"
    : >"$FAKE_STATE/uv-tools"
    run_sync capture --into "$SANDBOX_ROOT/stage-nouv"
    cp "$SANDBOX_ROOT/uv-tools.bak" "$FAKE_STATE/uv-tools"
    assert_status "$RUN_STATUS" 0 || return
    assert_file_exists "$SANDBOX_ROOT/stage-nouv/packages/uv-tools.txt" || return
    [[ -s "$SANDBOX_ROOT/stage-nouv/packages/uv-tools.txt" ]] &&
        { fail_test "expected an empty list"; return; }
    pass_test
}

test_units_delta() {
    start_test "units are enabled-minus-baseline, split system/user"
    assert_contains "$STAGE/units/system.txt" 'docker.service' || return
    assert_not_contains "$STAGE/units/system.txt" 'NetworkManager.service' || return
    assert_contains "$STAGE/units/user.txt" 'clawmem-watcher.service' || return
    assert_not_contains "$STAGE/units/user.txt" 'pipewire.socket' || return
    pass_test
}

test_dconf_captured() {
    start_test "dconf dump is captured"
    assert_file_exists "$STAGE/dconf/user.dconf" || return
    assert_contains "$STAGE/dconf/user.dconf" 'prefer-dark' || return
    pass_test
}

test_secrets_manifest_names_only() {
    start_test "secrets.manifest names what to bring and carries no values"
    assert_file_exists "$STAGE/secrets.manifest" || return
    assert_contains "$STAGE/secrets.manifest" '.secrets/.env.central' || return
    assert_contains "$STAGE/secrets.manifest" 'GITHUB_TOKEN' || return
    assert_not_contains "$STAGE/secrets.manifest" "$(fake_aws_key)" || return
    assert_not_contains "$STAGE/secrets.manifest" "$(fake_github_token)" || return
    pass_test
}

test_secrets_manifest_skips_ordinary_variables() {
    start_test "secrets.manifest does not list shouty non-secret variables"
    local v
    for v in 'KEYWORD' 'PASSED' 'EDITOR' 'OPS_API_URL'; do
        assert_not_contains "$STAGE/secrets.manifest" "\$$v" || return
    done
    pass_test
}

test_manifest_metadata() {
    start_test "jarvos-profile.json records schema + counts"
    assert_file_exists "$STAGE/jarvos-profile.json" || return
    assert_contains "$STAGE/jarvos-profile.json" '"schema"' || return
    assert_contains "$STAGE/jarvos-profile.json" '"packages"' || return
    pass_test
}

test_progress_file_written() {
    start_test "progress json ends with status done and the agreed keys"
    local p="$SANDBOX_ROOT/progress.json"
    assert_file_exists "$p" || return
    local k
    for k in '"tool"' '"action"' '"status"' '"phase"' '"phase_index"' '"phase_total"' \
        '"step"' '"step_total"' '"message"' '"exit_code"' '"log"' '"updated"'; do
        assert_contains "$p" "$k" || return
    done
    assert_contains "$p" '"status": "done"' || return
    pass_test
}

test_progress_flag_routes_output_to_the_log() {
    start_test "--progress silences stdout and writes the log named in the JSON"
    run_sync capture --into "$SANDBOX_ROOT/stage-quiet" --progress
    assert_status "$RUN_STATUS" 0 || return
    [[ -z "$RUN_OUT" ]] || { fail_test "expected no stdout, got: $RUN_OUT"; return; }
    local log
    log="$(sed -n 's/.*"log": "\(.*\)",/\1/p' "$SANDBOX_ROOT/progress.json")"
    assert_file_exists "$log" || return
    assert_contains "$log" "stage-quiet" || return
    pass_test
}

test_capture_is_idempotent() {
    start_test "capturing twice into the same dir yields an identical tree"
    local first second
    first="$(cd "$STAGE" && find . -type f | sort | xargs -r sha256sum | sha256sum)"
    run_sync capture --into "$STAGE"
    second="$(cd "$STAGE" && find . -type f | sort | xargs -r sha256sum | sha256sum)"
    [[ "$first" == "$second" ]] || { fail_test "tree changed between identical captures"; return; }
    pass_test
}

test_removed_file_disappears_from_stage() {
    start_test "a dotfile removed from home disappears from a re-capture"
    rm -f "$FAKE_HOME/.config/fish/functions/gs.fish"
    run_sync capture --into "$STAGE"
    assert_no_file "$STAGE/dotfiles/.config/fish/functions/gs.fish" || return
    pass_test
}

main() {
    make_sandbox
    trap clean_sandbox EXIT

    test_help_lists_subcommands

    seed_home
    capture_once
    if [[ $RUN_STATUS -ne 0 ]]; then
        printf 'capture failed (%d):\n%s\n' "$RUN_STATUS" "$RUN_OUT"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        summary "capture"
        exit 1
    fi

    test_identical_file_not_captured
    test_changed_file_captured
    test_new_file_captured
    test_host_specific_never_captured
    test_secrets_never_captured
    test_out_of_scope_never_captured
    test_claude_assets_captured
    test_staged_tree_has_no_secret_strings
    test_packages_delta
    test_module_packages_are_baseline
    test_legacy_tier_only_package_is_delta
    test_aur_delta
    test_uv_tools_delta
    test_uv_tool_from_a_continued_loop_is_baseline
    test_uv_tool_installed_by_path_is_baseline
    test_uv_tool_sharing_a_package_name_is_captured
    test_uv_tool_only_mentioned_by_a_post_block_is_captured
    test_uv_executables_are_not_tools
    test_uv_tools_file_written_when_nothing_to_carry
    test_units_delta
    test_dconf_captured
    test_secrets_manifest_names_only
    test_secrets_manifest_skips_ordinary_variables
    test_manifest_metadata
    test_progress_file_written
    test_progress_flag_routes_output_to_the_log
    test_capture_is_idempotent
    test_removed_file_disappears_from_stage

    summary "capture"
}

main "$@"
