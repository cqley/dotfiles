#!/bin/bash

SCRIPT_DIR="$HOME/.config/scripts"

options="wallpaper\nsettings\nconfig\nbtop\nfastfetch"

choice=$(echo -e "$options" | fuzzel -d -p "> ")

case "$choice" in
    *wallpaper*) "$SCRIPT_DIR/wallpaper.sh" ;;
    *settings*) "$SCRIPT_DIR/settings.sh" ;;
    *config*) "$SCRIPT_DIR/config.sh" ;;
    *btop*) kitty btop ;;
    *fastfetch*) kitty sh -c "fastfetch; read -p ''" ;;
esac
