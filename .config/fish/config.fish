function fish_greeting
end

function fish_prompt
    echo -n (prompt_pwd)
    echo -n " > "
end

abbr -a s sudo
abbr -a update sudo pacman -Syu
abbr -a pi sudo pacman -S
abbr -a pr sudo pacman -Rns
abbr -a pi paru -S
abbr -a ps paru -Ss
abbr -a yi yay -S
abbr -a ys yay -Ss
abbr -a zed zeditor

if status is-interactive
    cat ~/.cache/wal/sequences
end
