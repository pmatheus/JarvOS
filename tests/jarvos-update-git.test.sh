#!/usr/bin/env bash
# jarvos-update-git against real repositories: every way a checkout and its
# upstream can disagree, and what the step does about each.
# Run: tests/jarvos-update-git.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL="$SANDBOX_ROOT/gitconfig"
git config --global init.defaultBranch main
git config --global advice.detachedHead false

ORIGIN="$SANDBOX_ROOT/origin.git"
UP="$SANDBOX_ROOT/upstream-dev"
CO="$SANDBOX_ROOT/checkout"

g() { git -C "$1" "${@:2}" >/dev/null 2>&1; }

commit_file() {
    # commit_file <repo> <file> <content>
    printf '%s\n' "$3" >"$1/$2"
    g "$1" add "$2"
    g "$1" commit -m "$2: $3"
}

# A fresh origin with one commit, a developer clone that pushes to it, and the
# machine's checkout under test.
fresh_world() {
    rm -rf "$ORIGIN" "$UP" "$CO"
    git init -q --bare "$ORIGIN"
    git clone -q "$ORIGIN" "$UP" 2>/dev/null
    commit_file "$UP" a.txt "one"
    commit_file "$UP" b.txt "one"
    g "$UP" push -q origin main
    git clone -q "$ORIGIN" "$CO" 2>/dev/null
    : >"$FAKE_STATE/hyprctl-calls"
}

upstream_commit() {
    commit_file "$UP" "$1" "$2"
    g "$UP" push -q origin main
}

run_git_step() { JARVOS_PATH="$CO" run_cmd jarvos-update-git; }
head_of() { git -C "$1" rev-parse "${2:-HEAD}"; }

fresh_world
start_test "an up-to-date checkout is left alone"
before="$(head_of "$CO")"
run_git_step
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(head_of "$CO")" == "$before" ]] || fail_test "HEAD moved"; } &&
    pass_test

fresh_world
start_test "a checkout behind upstream fast-forwards and keeps local edits"
upstream_commit a.txt "two"
printf 'local\n' >"$CO/b.txt"
run_git_step
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(head_of "$CO")" == "$(head_of "$UP")" ]] || fail_test "not at upstream"; } &&
    assert_contains "$CO/a.txt" "two" &&
    assert_contains "$CO/b.txt" "local" &&
    pass_test

start_test "Hyprland is muted across the change and reloaded once after it"
if [[ "$(grep -cx 'reload' "$FAKE_STATE/hyprctl-calls")" -eq 1 ]]; then
    assert_contains "$FAKE_STATE/hyprctl-calls" "disable_autoreload 1" &&
        assert_contains "$FAKE_STATE/hyprctl-calls" "disable_autoreload 0" &&
        pass_test
else
    fail_test "expected exactly one bare reload, got: $(tr '\n' '|' <"$FAKE_STATE/hyprctl-calls")"
fi

fresh_world
start_test "local commits are rebased onto upstream when they do not conflict"
upstream_commit a.txt "upstream"
commit_file "$CO" b.txt "mine"
run_git_step
assert_status "$RUN_STATUS" 0 &&
    { git -C "$CO" merge-base --is-ancestor "$(head_of "$UP")" HEAD || fail_test "upstream not in HEAD"; } &&
    assert_contains "$CO/a.txt" "upstream" &&
    assert_contains "$CO/b.txt" "mine" &&
    pass_test

fresh_world
start_test "a conflicting rebase is abandoned and the checkout left as it was"
upstream_commit a.txt "upstream"
commit_file "$CO" a.txt "mine"
before="$(head_of "$CO")"
run_git_step
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    { [[ "$(head_of "$CO")" == "$before" ]] || fail_test "HEAD moved"; } &&
    { [[ ! -d "$CO/.git/rebase-merge" && ! -d "$CO/.git/rebase-apply" ]] || fail_test "rebase left in progress"; } &&
    assert_contains "$CO/a.txt" "mine" &&
    pass_test

fresh_world
start_test "rewritten upstream history is adopted, the old one kept on a backup branch"
printf 'local\n' >"$CO/b.txt"
old="$(head_of "$CO")"
# Rewrite: a brand-new root with the same content plus one change.
g "$UP" checkout -q --orphan rewritten
g "$UP" commit -q -m "rewritten root"
commit_file "$UP" a.txt "rewritten"
g "$UP" push -q --force origin rewritten:main
run_git_step
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(head_of "$CO")" == "$(head_of "$UP")" ]] || fail_test "not at rewritten upstream"; } &&
    { [[ "$(git -C "$CO" for-each-ref --format='%(objectname)' 'refs/heads/jarvos/backup/*')" == "$old" ]] ||
        fail_test "no backup branch at the old HEAD"; } &&
    assert_contains "$CO/a.txt" "rewritten" &&
    assert_contains "$CO/b.txt" "local" &&
    pass_test

fresh_world
start_test "a file the rewrite stopped tracking and now ignores stays on disk"
# Exactly what happened to JarvOS: agent instruction files were filtered out
# of history and added to .gitignore. They are still wanted, locally.
upstream_commit NOTES.md "keep me"
g "$CO" pull -q
g "$UP" checkout -q --orphan rewritten
g "$UP" rm -q --cached NOTES.md
rm -f "$UP/NOTES.md"
printf 'NOTES.md\n' >"$UP/.gitignore"
g "$UP" add .gitignore
g "$UP" commit -q -m "rewritten root"
g "$UP" push -q --force origin rewritten:main
run_git_step
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(head_of "$CO")" == "$(head_of "$UP")" ]] || fail_test "not at rewritten upstream"; } &&
    assert_contains "$CO/NOTES.md" "keep me" &&
    { git -C "$CO" check-ignore -q NOTES.md || fail_test "NOTES.md is not ignored"; } &&
    pass_test

fresh_world
start_test "a local edit that conflicts with rewritten upstream is kept in the stash"
printf 'local\n' >"$CO/a.txt"
g "$UP" checkout -q --orphan rewritten
g "$UP" commit -q -m "rewritten root"
commit_file "$UP" a.txt "rewritten"
g "$UP" push -q --force origin rewritten:main
run_git_step
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected failure, got 0"; } &&
    assert_contains "$CO/a.txt" "rewritten" &&
    { git -C "$CO" stash show -p 2>/dev/null | grep -q '^+local' || fail_test "edit not in the stash"; } &&
    { [[ -z "$(git -C "$CO" status --porcelain --untracked-files=no)" ]] || fail_test "tree left dirty"; } &&
    pass_test

fresh_world
start_test "an unreachable upstream exits 75 and changes nothing"
git -C "$CO" remote set-url origin "$SANDBOX_ROOT/does-not-exist.git"
before="$(head_of "$CO")"
run_git_step
assert_status "$RUN_STATUS" 75 &&
    { [[ "$(head_of "$CO")" == "$before" ]] || fail_test "HEAD moved"; } &&
    pass_test

fresh_world
start_test "a checkout with no upstream is not an error"
g "$CO" checkout -q -b local-only
run_git_step
assert_status "$RUN_STATUS" 0 && pass_test

summary "jarvos-update-git"
