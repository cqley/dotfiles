#!/bin/bash
SCRIPT_DIR="$HOME/.config/scripts"

options="󰸉 wallpaper\n󰳗 decorations\n󰒓 fastfetch"

choice=$(echo -e "$options" | rofi -dmenu -i -p "master" -theme-str 'window {width: 400px;}')

case "$choice" in
    *wallpaper*) "$SCRIPT_DIR/wallpaper.sh" ;;
    *decorations*) "$SCRIPT_DIR/settings.sh" ;;
    *fastfetch*) kitty sh -c "fastfetch; read -p 'press enter to close...'" ;;
esac
