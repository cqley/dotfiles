function fish_greeting
end

function fish_prompt
    echo -n (prompt_pwd)
    echo -n " > "
end

abbr -a s sudo
abbr -a update sudo pacman -Syu
abbr -a spi sudo pacman -S
abbr -a yi yay -S
abbr -a search yay -Ss
abbr -a fetch fastfetch

if status is-interactive
    cat ~/.cache/wal/sequences
end
