function fish_greeting
end

function fish_prompt
    echo -n (prompt_pwd)
    echo -n " > "
end

abbr -a s sudo
abbr -a update
abbr -a zed zeditor

if status is-interactive
    cat ~/.cache/wal/sequences
end
