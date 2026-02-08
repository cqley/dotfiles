function fish_greeting

if status is-interactive
    # You only need this if you want to use the color variables
    # (like $color1) in your fish prompt/functions
    [ -f ~/.cache/wal/colors-fish.conf ]; and source ~/.cache/wal/colors-fish.conf
end

end
