#!/bin/bash

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
DUNST_CONF="$HOME/.config/dunst/dunstrc"

options="sharp/round toggle\nborder toggle\ngaps toggle"
choice=$(echo -e "$options" | fuzzel -d -p "> ")

[[ -z "$choice" ]] && exit

case "$choice" in
    *sharp/round*)
        if grep -q "rounding = 0 # @dynamic_rounding" "$HYPR_CONF"; then
            sed -i '/@dynamic_rounding/c\    rounding = 15 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 10 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_dunst/c\    corner_radius = 15 # @dynamic_dunst' "$DUNST_CONF"
            sed -i '/@dynamic_smartgaps/s/^\([^#]\)/#\1/' "$HYPR_CONF"

            hyprctl keyword decoration:rounding 15 > /dev/null
            hyprctl reload > /dev/null
            notify-send "toggled" "rounded"
        else
            sed -i '/@dynamic_rounding/c\    rounding = 0 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 0 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_dunst/c\    corner_radius = 0 # @dynamic_dunst' "$DUNST_CONF"
            sed -i '/@dynamic_smartgaps/s/^#//g' "$HYPR_CONF"

            hyprctl keyword decoration:rounding 0 > /dev/null
            hyprctl reload > /dev/null
            notify-send "toggled" "sharp"
        fi
        killall dunst && dunst &
        ;;

    *border*)
        if grep -q "border_size = 0 # @dynamic_border" "$HYPR_CONF"; then
            sed -i '/@dynamic_border/c\    border_size = 2 # @dynamic_border' "$HYPR_CONF"
            hyprctl keyword general:border_size 2 > /dev/null
            notify-send "borders" "enabled"
        else
            sed -i '/@dynamic_border/c\    border_size = 0 # @dynamic_border' "$HYPR_CONF"
            hyprctl keyword general:border_size 0 > /dev/null
            notify-send "borders" "disabled"
        fi
        ;;

    *gaps*)
        if grep -q "gaps_in = 0 # @dynamic_gaps_in" "$HYPR_CONF"; then
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
