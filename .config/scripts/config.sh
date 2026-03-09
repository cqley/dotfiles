#!/bin/bash

declare -A configs=(
    ["hypr"]="$HOME/.config/hypr/"
    ["waybar"]="$HOME/.config/waybar/config"
    ["waybar-style"]="$HOME/.config/waybar/style.css"
    ["kitty"]="$HOME/.config/kitty/kitty.conf"
    ["fuzzel"]="$HOME/.config/fuzzel/fuzzel.ini"
    ["dunst"]="$HOME/.config/dunst/dunstrc"
    ["bashrc"]="$HOME/.bashrc"
    ["scripts"]="$HOME/.config/scripts/"
)

choice=$(printf "%s\n" "${!configs[@]}" | fuzzel -d -p "edit config > ")

[[ -z "$choice" ]] && exit

path="${configs[$choice]}"

if [ -e "$path" ]; then
    zeditor "$path"
else
    notify-send "error" "file not found: $path"
fi
