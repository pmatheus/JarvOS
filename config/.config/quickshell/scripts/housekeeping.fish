#!/usr/bin/env fish

# Arch Linux Housekeeping Script
# Compatible with Fish shell, Hyprland, and common tools

set -lx RED '\033[0;31m'
set -lx CYAN '\033[0;36m'
set -lx YELLOW '\033[1;33m'
set -lx MAGENTA '\033[0;35m'
set -lx NC '\033[0m' # No Color

function print_header
    gum style --foreground 5 --border-foreground 6 --border rounded --padding "0 4" "󰵲 hypr-arch update & maintenance script"
end

function print_section
    echo -e "\n$CYAN [INFO] $argv[1]$NC"
end

function print_success
    echo -e "$MAGENTA [SUCCESS] $argv[1]$NC"
end

function print_error
    echo -e "$RED [ERROR] $argv[1]$NC"
end

function check_command
    if not command -v $argv[1] &> /dev/null
        print_error "Command '$argv[1]' not found. Skipping related tasks."
        return 1
    end
    return 0
end

function update_system_packages
    print_section "Updating system packages with yay..."
    if check_command yay
        yay -Syu --noconfirm
        if test $status -eq 0
            print_success "System packages updated successfully"
        else
            print_error "Failed to update system packages"
        end
    end
end

function update_pipx_packages
    print_section "Updating pipx packages..."
    if not check_command pipx
        return
    end

    # Check for broken venvs (stale Python interpreter after system Python upgrade)
    set -l pipx_output (pipx list 2>&1)
    if string match -q "*invalid interpreter*" -- $pipx_output
        print_section "Detected broken pipx venvs (Python version changed). Rebuilding..."
        pipx reinstall-all 2>&1 | while read -l line
            # Surface only errors and success lines, skip noise
            if string match -q "*Error*" -- $line
                print_error $line
            else if string match -q "*done*" -- $line
                echo "  $line"
            end
        end
    end

    pipx upgrade-all
    if test $status -eq 0
        print_success "Pipx packages updated successfully"
    else
        print_error "Some pipx packages failed to upgrade (check Python compatibility)"
    end
end

function clean_package_cache
    print_section "Cleaning package cache..."

    # Remove stale partial downloads that cause paccache/yay errors
    # Use find instead of glob — Fish errors on unmatched wildcards
    sudo find /var/cache/pacman/pkg -maxdepth 1 \( -name 'download-*' -o -name '*.part' \) -exec rm -rf {} + 2>/dev/null

    # Clean yay/paru cache
    if check_command yay
        yay -Sc --noconfirm
    end

    # Clean pacman cache (keep only 3 most recent versions)
    if check_command paccache
        sudo paccache -r -k3
        # Clean uninstalled packages cache
        sudo paccache -r -u -k0
    end

    print_success "Package cache cleaned"
end

function remove_orphaned_packages
    print_section "Removing orphaned packages..."

    set -l orphans (pacman -Qtdq 2>/dev/null)
    if test (count $orphans) -gt 0
        sudo pacman -Rns $orphans --noconfirm
        set -l n (count $orphans)
        print_success "Removed $n orphaned packages"
    else
        print_success "No orphaned packages found"
    end
end

function clean_system_logs
    print_section "Cleaning system logs..."

    # Keep only last 2 weeks of logs
    sudo journalctl --vacuum-time=2weeks

    # Limit journal size to 100MB
    sudo journalctl --vacuum-size=100M

    print_success "System logs cleaned"
end

function clean_user_cache
    print_section "Cleaning user cache directories..."

    # Clean thumbnail cache older than 30 days
    find ~/.cache/thumbnails -type f -atime +30 -delete 2>/dev/null

    # Clean various application caches
    set -l cache_dirs ~/.cache/mozilla ~/.cache/chromium ~/.cache/google-chrome
    for dir in $cache_dirs
        if test -d $dir
            find $dir -type f -atime +7 -delete 2>/dev/null
        end
    end

    print_success "User cache cleaned"
end

function clean_temporary_files
    print_section "Cleaning temporary files..."

    # Clean /tmp (usually mounted as tmpfs, but just in case)
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null

    # Clean user temp files
    find ~/.tmp -type f -atime +7 -delete 2>/dev/null

    print_success "Temporary files cleaned"
end

function clean_trash
    print_section "Cleaning trash/recycle bin..."

    if test -d ~/.local/share/Trash
        # Capture find output into a list, then count (Fish's count reads args, not stdin)
        set -l trash_files (find ~/.local/share/Trash/files -mindepth 1 -maxdepth 1 2>/dev/null)
        set -l trash_count (count $trash_files)
        if test $trash_count -gt 0
            rm -rf ~/.local/share/Trash/files/*
            rm -rf ~/.local/share/Trash/info/*
            print_success "Trash emptied ($trash_count items)"
        else
            print_success "Trash is already empty"
        end
    else
        print_success "No trash directory found"
    end
end

function update_locate_database
    print_section "Updating locate database..."

    if check_command updatedb
        sudo updatedb
        print_success "Locate database updated"
    end
end

function clean_npm_cache
    print_section "Cleaning npm/yarn cache..."

    if check_command npm
        npm cache clean --force 2>/dev/null
        print_success "NPM cache cleaned"
    end

    if check_command yarn
        yarn cache clean 2>/dev/null
        print_success "Yarn cache cleaned"
    end
end

function check_disk_space
    print_section "Checking disk space..."

    echo "Disk usage:"
    df -h / /home 2>/dev/null | grep --color=never -E "(Filesystem|/dev/)"

    echo -e "\nLargest directories in /home:"
    du -sh ~/.* 2>/dev/null | sort -hr | head -5
end

function check_system_health
    print_section "Checking system health..."

    # Check for failed systemd services
    set -l failed_services (systemctl --failed --no-legend | wc -l)
    set failed_services (string trim $failed_services)
    if test "$failed_services" -gt 0 2>/dev/null
        print_error "$failed_services failed systemd services found"
        systemctl --failed --no-legend
    else
        print_success "No failed systemd services"
    end

    # Check for corrupted packages (filter out common documentation warnings)
    if check_command pacman
        # Use string collect to preserve newlines through pipes
        set -l critical_warnings (pacman -Qk 2>&1 | grep "warning" | grep -v -E "(doc/|ri/|man/|share/man/|\.ri \(No such file)" | wc -l)
        set -l doc_warnings (pacman -Qk 2>&1 | grep "warning" | grep -E "(doc/|ri/|man/|share/man/|\.ri \(No such file)" | wc -l)

        set critical_warnings (string trim $critical_warnings)
        set doc_warnings (string trim $doc_warnings)

        if test "$critical_warnings" -gt 0 2>/dev/null
            print_error "$critical_warnings critical package issues found"
            echo "Also found $doc_warnings documentation warnings (non-critical)"
            echo "Run 'pacman -Qk | grep -v \"doc/\\|ri/\\|man/\"' for critical issues only"
        else if test "$doc_warnings" -gt 0 2>/dev/null
            print_success "No critical package issues found"
            echo "Found $doc_warnings documentation warnings (non-critical)"
        else
            print_success "No package issues found"
        end
    end
end

# Main execution
function main
    print_header

    # Check if running with appropriate permissions
    if test (id -u) -eq 0
        print_error "Don't run this script as root!"
        exit 1
    end

    # Prompt user for confirmation
    if not gum confirm "This script will perform system maintenance tasks. Continue?" --selected.background 6 --prompt.foreground 6
        echo "Aborted by user"
        exit 0
    end

    # Execute maintenance tasks
    # IMPORTANT: Cleanup and health checks run FIRST, system update runs LAST.
    # yay -Syu replaces shared libraries on disk — any command running after
    # the update may segfault because its loaded .so files were swapped out.
    clean_package_cache
    remove_orphaned_packages
    clean_system_logs
    clean_user_cache
    clean_temporary_files
    clean_trash
    clean_npm_cache
    update_locate_database
    check_system_health
    check_disk_space

    # Updates run last to avoid stale library segfaults
    update_pipx_packages
    update_system_packages

    echo
    print_success "Housekeeping completed!"
    echo -e "Your system is now clean and optimized!"
    echo
end

# Run main function
main
