#!/bin/bash

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
DUNST_CONF="$HOME/.config/dunst/dunstrc"
ROFI_CONF="$HOME/.config/rofi/config.rasi"
WALL_CONF="$HOME/.config/rofi/wallpaper.rasi"
BTOP_CONF="$HOME/.config/btop/btop.conf"
ANIMATION_SCRIPT="$HOME/.config/scripts/animations.sh"

options="border toggle\ngaps toggle\nanimations"
choice=$(echo -e "$options" | rofi -dmenu -i -p ">")

[[ -z "$choice" ]] && exit

case "$choice" in
    *animations*)
        $ANIMATION_SCRIPT
        ;;

    *border*)
        if grep -q "border_size = 0 #" "$HYPR_CONF"; then
            sed -i '/@dynamic_border/c\    border_size = 2 # @dynamic_border' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^\([^#]\)/#\1/' "$HYPR_CONF"
            hyprctl keyword general:border_size 2 > /dev/null
            hyprctl reload > /dev/null
            notify-send "borders" "enabled"
        else
            sed -i '/@dynamic_border/c\    border_size = 0 # @dynamic_border' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^#//g' "$HYPR_CONF"
            hyprctl keyword general:border_size 0 > /dev/null
            hyprctl reload > /dev/null
            notify-send "borders" "disabled"
        fi
        ;;

    *gaps*)
        if grep -q "gaps_in = 0 #" "$HYPR_CONF"; then
            sed -i '/@dynamic_gaps_in/c\    gaps_in = 5 # @dynamic_gaps_in' "$HYPR_CONF"
            sed -i '/@dynamic_gaps_out/c\    gaps_out = 10 # @dynamic_gaps_out' "$HYPR_CONF"
            hyprctl keyword general:gaps_in 5 > /dev/null
            hyprctl keyword general:gaps_out 10 > /dev/null
            notify-send "gaps" "on"
        else
            sed -i '/@dynamic_gaps_in/c\    gaps_in = 0 # @dynamic_gaps_in' "$HYPR_CONF"
            sed -i '/@dynamic_gaps_out/c\    gaps_out = 0 # @dynamic_gaps_out' "$HYPR_CONF"
            hyprctl keyword general:gaps_in 0 > /dev/null
            hyprctl keyword general:gaps_out 0 > /dev/null
            notify-send "gaps" "off"
        fi
        ;;
esac
