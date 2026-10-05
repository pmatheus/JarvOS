echo "Keeping the running kernel's modules across kernel upgrades"

# The daily automatic update can install a new kernel on a machine that will
# not reboot for days. Pacman removes the running kernel's modules with the old
# package, so until that reboot nothing new can be loaded: a USB device, a
# filesystem, a VM's network. kernel-modules-hook keeps them on disk across the
# upgrade, and its cleanup service removes them after the reboot. Both guards
# are the idempotency.

jarvos-pkg-present kernel-modules-hook || jarvos-pkg-add kernel-modules-hook

if ! systemctl is-enabled --quiet linux-modules-cleanup.service 2>/dev/null; then
    sudo systemctl enable linux-modules-cleanup.service
fi
