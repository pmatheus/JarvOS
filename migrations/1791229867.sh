echo "Enabling the daily automatic update"

# JarvOS now updates itself once a day through a user timer, with conflict
# resolution and live rollback built into jarvos-update. A machine installed
# before this release has neither unit in its config, because the installer
# copies config/ once, at install time. Copy them in only when absent, so a
# user's edited unit is never replaced, and enable the timer only when it is
# not already enabled: the guard is the idempotency.

units="$HOME/.config/systemd/user"
mkdir -p "$units"
for unit in jarvos-update.service jarvos-update.timer; do
    [[ -e "$units/$unit" ]] || cp "$JARVOS_PATH/config/.config/systemd/user/$unit" "$units/$unit"
done

if ! systemctl --user is-enabled --quiet jarvos-update.timer 2>/dev/null; then
    systemctl --user daemon-reload
    systemctl --user enable --now jarvos-update.timer
fi
