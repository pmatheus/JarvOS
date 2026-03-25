#!/usr/bin/env fish

# Carrega as variáveis do ambiente se existir
if test -f ~/Lab/env.fish
    source ~/Lab/env.fish
end

# Gera o nome do arquivo
set filename (date "+%Y%m%d-%H:%M:%S").png

# Decide o output
if test -n "$boxpwd" -a -d "$boxpwd"
    # Cria a pasta screenshots se não existir
    mkdir -p "$boxpwd/screenshots"
    set output_filename "$boxpwd/screenshots/satty-$filename"
else
    # Cria a pasta Screenshots se não existir
    mkdir -p "$HOME/Pictures/Screenshots"
    set output_filename "$HOME/Pictures/Screenshots/satty-$filename"
end

grimblast --freeze save area - | satty \
    --initial-tool rectangle \
    --copy-command wl-copy \
    --output-filename $output_filename \
    --actions-on-enter "save-to-clipboard" \
    --actions-on-escape "exit" \
    --early-exit \
    --filename -