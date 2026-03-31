#!/bin/bash

configs=(
    "hypr:$HOME/.config/hypr/"
    "scripts:$HOME/.config/scripts/"
    "rofi:$HOME/.config/rofi/"
    "dunst:$HOME/.config/dunst/dunstrc"
    "fish:$HOME/.config/fish/config.fish"
    "kitty:$HOME/.config/kitty/kitty.conf"
    "zed:$HOME/.config/zed/settings.json"
    "btop:$HOME/.config/btop/btop.conf"
    "fastfetch:$HOME/.config/fastfetch/config.jsonc"
    "csgo:$HOME/.local/share/Steam/steamapps/common/csgo legacy/csgo/cfg/autoexec.cfg"
    "cs2:$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg"
)

choice=$(printf "%s\n" "${configs[@]}" | cut -d':' -f1 | rofi -dmenu -i -p ">")

[[ -z "$choice" ]] && exit

for item in "${configs[@]}"; do
    if [[ "$item" == "$choice:"* ]]; then
        path="${item#*:}"
        break
    fi
done

if [ -e "$path" ]; then
    zeditor "$path"
else
    notify-send "error" "file not found: $path"
fi
