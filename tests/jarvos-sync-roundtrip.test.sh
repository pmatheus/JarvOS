#!/usr/bin/env bash
# jarvos-sync — the round trip: init into a repo, restore into a fresh HOME,
# restore again as a no-op. Run: tests/jarvos-sync-roundtrip.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

BARE=""


seed_source_home() {
    home_file .config/fish/config.fish <<<'set -g fish_greeting "hello"'
    home_file .config/fish/functions/gs.fish <<<'function gs; git status; end'
    home_file .claude/CLAUDE.md <<<'# Identity'
    # A dotfile tree of the user's that carries its own .gitignore. The profile
    # repo must still carry every file capture staged — git's nested ignore
    # rules are about *their* project, not about our snapshot.
    home_file .config/nvim/.gitignore <<<'lazy-lock.json
.gitignore'
    home_file .config/nvim/lazy-lock.json <<<'{"plugin":"v1"}'
    home_file .config/hypr/hyprland/monitors.conf <<<'monitor=DP-1,3440x1440@144,0x0,1'
    # assembled at runtime — see the fake_* helpers in lib/sandbox.sh
    printf 'AWS_KEY=%s\n' "$(fake_aws_key)" | home_file .secrets/.env.central
    fake_private_key | home_file .ssh/id_ed25519
    printf 'base\nlinux\nhyprland\nkitty\nfish\nquickshell-git\nmatugen-bin\nneovim\nferoxbuster\n' \
        >"$FAKE_STATE/pacman-explicit"
    printf 'quickshell-git\nmatugen-bin\nferoxbuster\n' >"$FAKE_STATE/pacman-foreign"
    printf 'NetworkManager.service\ndocker.service\n' >"$FAKE_STATE/units-system"
    printf 'pipewire.socket\nclawmem-watcher.service\n' >"$FAKE_STATE/units-user"
}

# Swap the sandbox onto a second, empty home — the "new machine".
switch_to_fresh_home() {

    export FAKE_HOME="$SANDBOX_ROOT/newhome"
    mkdir -p "$FAKE_HOME"
    printf 'base\nlinux\nhyprland\nkitty\nfish\nquickshell-git\nmatugen-bin\n' \
        >"$FAKE_STATE/pacman-explicit"
    printf 'quickshell-git\nmatugen-bin\n' >"$FAKE_STATE/pacman-foreign"
    printf 'NetworkManager.service\n' >"$FAKE_STATE/units-system"
    printf 'pipewire.socket\n' >"$FAKE_STATE/units-user"
    : >"$FAKE_STATE/pacman-installed"
    : >"$FAKE_STATE/yay-installed"
    : >"$FAKE_STATE/units-enabled-calls"
    # the distro ships these; restore must lay its delta on top
    mkdir -p "$FAKE_HOME/.config/fish"
    cp "$FAKE_BASE/config/.config/fish/config.fish" "$FAKE_HOME/.config/fish/config.fish"
}

# --- tests --------------------------------------------------------------

test_init_creates_repo() {
    start_test "init seeds a git profile repo and pushes to the remote"
    BARE="$SANDBOX_ROOT/remote.git"
    git init --quiet --bare "$BARE"
    run_sync init --local "$BARE"
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    assert_file_exists "$SANDBOX_ROOT/profile/packages/explicit.txt" || return
    local n
    n="$(git --git-dir="$BARE" rev-list --count HEAD 2>/dev/null || echo 0)"
    [[ "$n" -ge 1 ]] || { fail_test "no commit reached the remote"; return; }
    pass_test
}

test_init_repo_has_no_secrets() {
    start_test "the pushed repo carries no secret-shaped content"
    local co="$SANDBOX_ROOT/verify"
    git clone --quiet "$BARE" "$co"
    rm -rf "$co/.git"
    assert_no_secret_shaped_content "$co" || return
    assert_no_file "$co/dotfiles/.secrets/.env.central" || return
    assert_no_file "$co/dotfiles/.ssh/id_ed25519" || return
    assert_no_file "$co/dotfiles/.config/hypr/hyprland/monitors.conf" || return
    pass_test
}

test_nested_gitignore_does_not_drop_files() {
    start_test "a .gitignore inside a captured tree does not drop files from the repo"
    local co="$SANDBOX_ROOT/verify-ignore"
    git clone --quiet "$BARE" "$co"
    assert_file_exists "$co/dotfiles/.config/nvim/lazy-lock.json" || return
    assert_file_exists "$co/dotfiles/.config/nvim/.gitignore" || return
    pass_test
}

test_status_reports_clean_then_drift() {
    start_test "status is clean right after init and shows drift after a change"
    run_sync status
    assert_stdout_contains "$RUN_OUT" "in sync" || return
    home_file .config/kitty/kitty.conf <<<'font_size 13'
    run_sync status
    assert_stdout_contains "$RUN_OUT" "drift" || return
    assert_stdout_contains "$RUN_OUT" "kitty.conf" || return
    pass_test
}

test_push_clears_drift() {
    start_test "push commits the drift and status goes clean"
    run_sync push -m "test push"
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    run_sync status
    assert_stdout_contains "$RUN_OUT" "in sync" || return
    pass_test
}

test_restore_dry_run_writes_nothing() {
    start_test "restore --dry-run writes nothing and installs nothing"
    export JARVOS_SYNC_DIR="$SANDBOX_ROOT/profile-restored"
    run_sync restore "$BARE" --dry-run
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    assert_no_file "$FAKE_HOME/.config/fish/functions/gs.fish" || return
    [[ ! -s "$FAKE_STATE/pacman-installed" ]] || { fail_test "dry-run installed packages"; return; }
    assert_stdout_contains "$RUN_OUT" "would" || return
    pass_test
}

test_restore_applies_dotfiles() {
    start_test "restore lays the dotfile delta into a fresh HOME"
    run_sync restore "$BARE"
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    assert_file_exists "$FAKE_HOME/.config/fish/functions/gs.fish" || return
    assert_file_exists "$FAKE_HOME/.claude/CLAUDE.md" || return
    assert_contains "$FAKE_HOME/.config/fish/config.fish" 'hello' || return
    pass_test
}

test_restore_installs_packages() {
    start_test "restore installs the package delta (repo via pacman, AUR via yay)"
    assert_contains "$FAKE_STATE/pacman-installed" 'neovim' || return
    assert_contains "$FAKE_STATE/yay-installed" 'feroxbuster' || return
    pass_test
}

test_restore_enables_units() {
    start_test "restore enables the captured units in both scopes"
    assert_contains "$FAKE_STATE/units-enabled-calls" 'system docker.service' || return
    assert_contains "$FAKE_STATE/units-enabled-calls" 'user clawmem-watcher.service' || return
    pass_test
}

test_restore_reports_secrets() {
    start_test "restore prints what still needs to come from the vault"
    assert_stdout_contains "$RUN_OUT" ".secrets/.env.central" || return
    pass_test
}

test_restore_skips_host_specific() {
    start_test "restore never lays down host-specific state"
    assert_no_file "$FAKE_HOME/.config/hypr/hyprland/monitors.conf" || return
    pass_test
}

test_second_restore_is_noop() {
    start_test "a second restore changes nothing and takes no new backup"
    : >"$FAKE_STATE/pacman-installed"
    : >"$FAKE_STATE/yay-installed"
    : >"$FAKE_STATE/units-enabled-calls"
    local before after
    before="$(ls "$FAKE_HOME/.jarvos-sync-backup" 2>/dev/null | wc -l)"
    run_sync restore "$BARE"
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    assert_stdout_contains "$RUN_OUT" "dotfiles: 0 changed" || return
    assert_stdout_contains "$RUN_OUT" "units: 0 enabled" || return
    assert_stdout_contains "$RUN_OUT" "packages: 0 new" || return
    [[ ! -s "$FAKE_STATE/pacman-installed" ]] || { fail_test "reinstalled packages"; return; }
    [[ ! -s "$FAKE_STATE/units-enabled-calls" ]] || { fail_test "re-enabled units"; return; }
    after="$(ls "$FAKE_HOME/.jarvos-sync-backup" 2>/dev/null | wc -l)"
    [[ "$before" == "$after" ]] || { fail_test "a no-op restore still took a backup"; return; }
    pass_test
}

test_restore_backs_up_conflicts() {
    start_test "restore backs up a file it would overwrite"
    printf 'my own version\n' >"$FAKE_HOME/.config/fish/functions/gs.fish"
    run_sync restore "$BARE"
    assert_status "$RUN_STATUS" 0 || { printf '%s\n' "$RUN_OUT"; return; }
    local backup
    backup="$(find "$FAKE_HOME/.jarvos-sync-backup" -name gs.fish -type f 2>/dev/null | head -1)"
    [[ -n "$backup" ]] || { fail_test "no backup taken for the overwritten file"; return; }
    assert_contains "$backup" 'my own version' || return
    assert_contains "$FAKE_HOME/.config/fish/functions/gs.fish" 'git status' || return
    pass_test
}

test_restore_progress_json() {
    start_test "restore progress json reports the four phases and ends done"
    local p="$SANDBOX_ROOT/progress.json"
    assert_file_exists "$p" || return
    assert_contains "$p" '"action": "restore"' || return
    assert_contains "$p" '"phase_total": 4' || return
    assert_contains "$p" '"status": "done"' || return
    pass_test
}

test_restore_failure_marks_progress_failed() {
    start_test "a restore that cannot reach its source ends progress as failed"
    run_sync restore "$SANDBOX_ROOT/does-not-exist.git"
    [[ $RUN_STATUS -ne 0 ]] || { fail_test "expected non-zero exit"; return; }
    assert_contains "$SANDBOX_ROOT/progress.json" '"status": "failed"' || return
    pass_test
}

main() {
    make_sandbox
    trap clean_sandbox EXIT

    seed_source_home
    test_init_creates_repo
    test_init_repo_has_no_secrets
    test_nested_gitignore_does_not_drop_files
    test_status_reports_clean_then_drift
    test_push_clears_drift

    switch_to_fresh_home
    test_restore_dry_run_writes_nothing
    test_restore_applies_dotfiles
    test_restore_installs_packages
    test_restore_enables_units
    test_restore_reports_secrets
    test_restore_skips_host_specific
    test_second_restore_is_noop
    test_restore_backs_up_conflicts
    test_restore_progress_json
    test_restore_failure_marks_progress_failed

    summary "roundtrip"
}

main "$@"
