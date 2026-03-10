#!/bin/bash

SCRIPT_DIR="$HOME/.config/scripts"

options="btop\nconfig\nsettings\nwallpaper\nfastfetch"

choice=$(echo -e "$options" | fuzzel -d -p "> ")

case "$choice" in
    *btop*) kitty btop ;;
    *config*) "$SCRIPT_DIR/config.sh" ;;
    *settings*) "$SCRIPT_DIR/settings.sh" ;;
    *wallpaper*) "$SCRIPT_DIR/wallpaper.sh" ;;
    *fastfetch*) kitty sh -c "fastfetch; read -p ''" ;;
esac
