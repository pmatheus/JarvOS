#!/usr/bin/env bash

# Kitty scrollback search with fzf.fish-style interface
# Usage: map ctrl+f launch --type=overlay --stdin-source=@screen_scrollback --stdin-add-formatting --copy-env ~/.config/kitty/kitty_scrollback_search.sh

# Preview function with context lines (similar to show_context from original search.sh)
show_context() {
    local line_num=$1
    local height=${FZF_PREVIEW_LINES:-15}
    
    
    # Ensure height doesn't exceed total lines
    ((height > total_lines)) && height=$total_lines
    
    # Calculate start and end positions for context
    local start=$((line_num - height / 2))
    local end=$((start + height))
    
    # Adjust boundaries
    if ((start < 1)); then
        start=1
        end=$height
    elif ((end > total_lines)); then
        end=$total_lines
        start=$((end - height + 1))
        ((start < 1)) && start=1
    fi
    
    # Use bat for syntax highlighting with context
    bat --color=always \
        --decorations=never \
        --line-range="$start:$end" \
        --highlight-line="$line_num" \
        --style=numbers \
        "$stdin_file"
}

# Create temporary file for stdin content
stdin_file=$(mktemp)
trap "rm -f '$stdin_file'" EXIT
cat > "$stdin_file"

# Count total lines
total_lines=$(wc -l < "$stdin_file")

# Export variables and functions for fzf preview
export stdin_file
export total_lines
export -f show_context

# Set shell for fzf preview commands (following fzf.fish pattern)
export SHELL=bash

# Configure FZF_DEFAULT_OPTS if not already set (matching fzf.fish defaults)
if [[ -z "$FZF_DEFAULT_OPTS" && -z "$FZF_DEFAULT_OPTS_FILE" ]]; then
    export FZF_DEFAULT_OPTS="--cycle --layout=reverse --border --height=100% --preview-window=wrap --marker=*"
fi

# Execute fzf with fzf.fish-style interface
fzf \
    --ansi \
    --no-sort \
    --exact \
    --prompt="Scrollback> " \
    --preview='show_context $(({n} + 1))' \
    --preview-window="right:60%:wrap:border-left" \
    --bind="ctrl-/:toggle-preview" \
    --bind="alt-up:preview-up,alt-down:preview-down" \
    --bind="shift-up:preview-page-up,shift-down:preview-page-down" \
    --header="Ctrl-/ toggle preview │ Alt-↑↓ scroll │ Shift-↑↓ page" \
    --header-lines=0 \
    < "$stdin_file"

# Always exit with success, even if user cancelled with ESC (exit code 130)
exit 0