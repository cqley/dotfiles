#!/bin/bash

SCRIPT_DIR="$HOME/.config/scripts"

options="btop\nnetwork\nconfig\nsettings\nwallpaper\nssh"

choice=$(echo -e "$options" | rofi -dmenu -i -p ">")

case "$choice" in
    *btop*) kitty btop ;;
    *network*) "$SCRIPT_DIR/network.sh" ;;
    *config*) "$SCRIPT_DIR/config.sh" ;;
    *settings*) "$SCRIPT_DIR/settings.sh" ;;
    *wallpaper*) "$SCRIPT_DIR/wallpaper.sh" ;;
    *ssh*) "$SCRIPT_DIR/ssh.sh" ;;
esac
