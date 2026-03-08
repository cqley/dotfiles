#!/bin/bash

SCRIPT_DIR="$HOME/.config/scripts"

options="wallpaper\nsettings\nfastfetch"

choice=$(echo -e "$options" | fuzzel -d -p "> ")

case "$choice" in
    *wallpaper*) "$SCRIPT_DIR/wallpaper.sh" ;;
    *settings*) "$SCRIPT_DIR/settings.sh" ;;
    *fastfetch*) kitty sh -c "fastfetch; read -p 'press enter to close...'" ;;
esac
