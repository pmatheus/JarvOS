# function fish_prompt -d "Write out the prompt"
#     # This shows up as USER@HOST /home/user/ >, with the directory colored
#     # $USER and $hostname are set by fish, so you can just use them
#     # instead of using `whoami` and `hostname`
#     printf '%s@%s %s%s%s > ' $USER $hostname \
#         (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
# end

starship init fish | source
if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
end

if status is-interactive
    # Commands to run in interactive sessions can go here
    set fish_greeting
    fastfetch
end

set -x PYTHONWARNINGS "ignore"
set -gx EDITOR "nano"

# Go, Ruby gem, and Google Cloud SDK binaries
fish_add_path -g ~/go/bin
fish_add_path -g ~/.local/share/gem/ruby/3.4.0/bin
fish_add_path -g ~/google-cloud-sdk/bin

# ezpz - Pentest enumeration toolkit
set -gx EZPZ_HOME /home/user/ezpz
set -gx fish_function_path "$EZPZ_HOME/functions" $fish_function_path

# Aliases
source ~/.config/fish/aliases.fish
alias clear "printf '\033[2J\033[3J\033[1;1H'"
abbr --add cc 'claude --dangerously-skip-permissions'
alias codex 'codex --dangerously-bypass-approvals-and-sandbox'

# Fzf.fish
fzf_configure_bindings --directory=\ce --variables=\e\cv

# IPED Configuration - env vars set GLOBALLY for subprocess inheritance
set -gx JAVA_HOME /usr/lib/jvm/liberica-jdk-11-full
set -gx _JAVA_AWT_WM_NONREPARENTING 1  # Wayland compatibility
set -gx SAL_USE_VCLPLUGIN gen  # LibreOffice text viewer compatibility
set -g IPED_HOME $HOME/iped

# IPED JEP/Java library paths — only LD_LIBRARY_PATH is global (harmless: just adds search dirs)
# LD_PRELOAD and PYTHONPATH are set per-command inside iped/iped-viewer functions to avoid
# poisoning every process with libpython3.9
set -gx LD_LIBRARY_PATH $JAVA_HOME/lib/server $JAVA_HOME/lib $IPED_HOME/python-env/lib/python3.9/site-packages/jep /usr/local/lib $LD_LIBRARY_PATH
set -gx SAL_DISABLE_COMPONENTUPDATE 1  # Prevent LibreOffice update checks

# IPED commands - wrappers handle memory args placement
function iped
    # IPED indexer/processor with LibreOffice 7.6.7 for text extraction
    set -l LO7_HOME "$IPED_HOME/libreoffice7/opt/libreoffice7.6"
    set -gx UNO_PATH "$LO7_HOME/program"
    set -gx OFFICE_PROGRAM_PATH "$LO7_HOME/program"
    set -gx PATH "$LO7_HOME/program" $PATH

    # -DlibreOfficePath bypasses NOA auto-detection that finds LO25
    # LD_PRELOAD + PYTHONPATH scoped to this process only (not global)
    env LD_PRELOAD=/usr/lib/libpython3.9.so.1.0 \
        PYTHONPATH=$IPED_HOME/python-env/lib/python3.9/site-packages \
        java -DlibreOfficePath="$LO7_HOME" -Doffice.home="$LO7_HOME" \
        -jar $IPED_HOME/iped.jar -Xms8G -Xmx31G $argv
end

function iped-viewer
    # IPED viewer with LibreOffice 7 for Text tab compatibility
    # Usage: iped-viewer [case-path]

    # LibreOffice 7.6.7 path - bypasses NOA auto-detection that finds LO25
    set -l LO7_HOME "$IPED_HOME/libreoffice7/opt/libreoffice7.6"
    set -gx UNO_PATH "$LO7_HOME/program"
    set -gx OFFICE_PROGRAM_PATH "$LO7_HOME/program"
    set -gx PATH "$LO7_HOME/program" $PATH

    set -l case_dir ""
    if test (count $argv) -gt 0
        if test -d "$argv[1]/iped/index"
            set case_dir "$argv[1]/iped"
        else if test -d "$argv[1]/index"
            set case_dir "$argv[1]"
        else
            echo "Error: Not a valid IPED case directory: $argv[1]"
            return 1
        end
        echo "Opening case: $case_dir"
        echo "Using LibreOffice 7.6.7 for Text viewer"
        # -DlibreOfficePath is the KEY - LibreOfficeFinder checks this FIRST before NOA detection
        # Memory args MUST go AFTER jar (IPED forks subprocess with those params)
        cd "$case_dir" && env LD_PRELOAD=/usr/lib/libpython3.9.so.1.0 \
            PYTHONPATH=$IPED_HOME/python-env/lib/python3.9/site-packages \
            java -DlibreOfficePath="$LO7_HOME" -Doffice.home="$LO7_HOME" -jar $IPED_HOME/lib/iped-search-app.jar -Xms2G -Xmx8G
    else
        env LD_PRELOAD=/usr/lib/libpython3.9.so.1.0 \
            PYTHONPATH=$IPED_HOME/python-env/lib/python3.9/site-packages \
            java -DlibreOfficePath="$LO7_HOME" -Doffice.home="$LO7_HOME" -jar $IPED_HOME/lib/iped-search-app.jar -Xms2G -Xmx8G
    end
end
