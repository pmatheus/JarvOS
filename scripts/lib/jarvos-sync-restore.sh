#!/usr/bin/env bash
# jarvos-sync — the restore side: the four idempotent phases that turn a profile
# repo back into a machine (packages, uv tools, dotfiles, units, post steps).
# Sourced by scripts/jarvos-sync; not run on its own.
#
# Reads the caller's globals: DRY_RUN, FORCE, BACKUP_ROOT, TMP_ROOT, and the
# RESTORE_* counters it increments.
#
# shellcheck shell=bash

# ── restore ──────────────────────────────────────────────────────────────

RESTORE_PKGS=0
RESTORE_DOTS=0
RESTORE_UNITS=0
RESTORE_UV=0
BACKUP_DIR=""

as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

restore_packages() {
    local src="$1" want missing repo aur
    [[ -f "$src/packages/explicit.txt" ]] || return 0
    want="$TMP_ROOT/want"; missing="$TMP_ROOT/missing"
    repo="$TMP_ROOT/repo.pkgs"; aur="$TMP_ROOT/aur.want"
    sort -u "$src/packages/explicit.txt" >"$want"
    comm -23 "$want" <(pacman -Qq 2>/dev/null | sort -u) >"$missing"
    RESTORE_PKGS="$(wc -l <"$missing")"
    [[ "$RESTORE_PKGS" -eq 0 ]] && { say "  packages: nothing missing"; return 0; }
    sort -u "$src/packages/aur.txt" 2>/dev/null >"$TMP_ROOT/aur.all" || : >"$TMP_ROOT/aur.all"
    comm -12 "$missing" "$TMP_ROOT/aur.all" >"$aur"
    comm -23 "$missing" "$aur" >"$repo"
    if [[ $DRY_RUN -eq 1 ]]; then
        say "  packages: would install $RESTORE_PKGS ($(wc -l <"$repo") repo, $(wc -l <"$aur") AUR)"
        return 0
    fi
    if [[ -s "$repo" ]]; then
        say "  packages: installing $(wc -l <"$repo") from the repos"
        # shellcheck disable=SC2046  # word splitting is the interface
        as_root pacman -S --needed --noconfirm $(tr '\n' ' ' <"$repo") || warn "some repo packages failed"
    fi
    if [[ -s "$aur" ]]; then
        if command -v yay >/dev/null 2>&1; then
            say "  packages: installing $(wc -l <"$aur") from the AUR"
            # shellcheck disable=SC2046
            yay -S --needed --noconfirm $(tr '\n' ' ' <"$aur") || warn "some AUR packages failed"
        else
            warn "yay is missing; skipping $(wc -l <"$aur") AUR package(s)"
        fi
    fi
}

# A missing dev tool is not worth failing a machine rebuild over: every failure
# warns and the phase carries on. Only tools that actually installed are counted.
restore_uv_tools() {
    local src="$1" list have t
    list="$src/packages/uv-tools.txt"
    [[ -s "$list" ]] || return 0
    if ! command -v uv >/dev/null 2>&1; then
        warn "uv is missing; skipping $(wc -l <"$list") uv tool(s)"
        return 0
    fi
    have="$TMP_ROOT/uv.have"
    uv_installed_tools | sort -u >"$have"
    while read -r t; do
        [[ -n "$t" ]] || continue
        grep -qxF "$t" "$have" && continue
        if [[ $DRY_RUN -eq 1 ]]; then
            RESTORE_UV=$((RESTORE_UV + 1))
            say "  would install uv tool $t"
            continue
        fi
        if uv tool install --quiet "$t" >/dev/null 2>&1; then
            RESTORE_UV=$((RESTORE_UV + 1))
            say "  uv tool: installed $t"
        else
            warn "uv tool $t could not be installed — skipped, continuing"
        fi
    done <"$list"
}

restore_dotfiles() {
    local src="$1/dotfiles" rel target
    [[ -d "$src" ]] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        target="$HOME/$rel"
        if [[ -f "$target" ]] && cmp -s "$f" "$target"; then continue; fi
        RESTORE_DOTS=$((RESTORE_DOTS + 1))
        STEP=$((STEP + 1))
        if [[ $DRY_RUN -eq 1 ]]; then
            say "  would write ~/$rel"
            continue
        fi
        if [[ -e "$target" && $FORCE -eq 0 ]]; then
            [[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -p "$target" "$BACKUP_DIR/$rel"
            say "  backed up ~/$rel"
        fi
        mkdir -p "$(dirname "$target")"
        cp -p "$f" "$target"
        progress "running" "$PHASE" "$PHASE_INDEX" "$STEP" "restored $rel"
    done < <(find "$src" -type f -print0 2>/dev/null)
}

restore_units() {
    local src="$1/units" scope unit
    for scope in system user; do
        [[ -f "$src/$scope.txt" ]] || continue
        while IFS= read -r unit; do
            [[ -n "$unit" ]] || continue
            if [[ "$scope" == user ]]; then
                systemctl --user is-enabled "$unit" >/dev/null 2>&1 && continue
            else
                systemctl is-enabled "$unit" >/dev/null 2>&1 && continue
            fi
            RESTORE_UNITS=$((RESTORE_UNITS + 1))
            if [[ $DRY_RUN -eq 1 ]]; then say "  would enable $scope unit $unit"; continue; fi
            if [[ "$scope" == user ]]; then
                systemctl --user enable "$unit" >/dev/null 2>&1 || warn "could not enable user unit $unit"
            else
                as_root systemctl enable "$unit" >/dev/null 2>&1 || warn "could not enable $unit"
            fi
        done <"$src/$scope.txt"
    done
}

restore_post() {
    local src="$1"
    if [[ -f "$src/dconf/user.dconf" && $DRY_RUN -eq 0 ]] && command -v dconf >/dev/null 2>&1; then
        dconf load / <"$src/dconf/user.dconf" 2>/dev/null || warn "dconf load failed"
    fi
    say ""
    say "Host-specific state was not restored, by design: monitors.conf, colors.conf,"
    say "the colour scheme and machine-id are regenerated for this machine."
    if [[ -f "$src/secrets.manifest" ]]; then
        say ""
        say "Still needed from your vault — nothing below is in the repo:"
        say ""
        sed 's/^/  /' "$src/secrets.manifest"
    fi
}

