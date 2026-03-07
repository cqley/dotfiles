#!/bin/bash
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
DUNST_CONF="$HOME/.config/dunst/dunstrc"

options="󰃟 sharp/round toggle"
choice=$(echo -e "$options" | rofi -dmenu -i -p "settings")

[[ -z "$choice" ]] && exit

case "$choice" in
    *toggle*)
        if grep -q "rounding = 0 # @dynamic_rounding" "$HYPR_CONF"; then
            sed -i '/@dynamic_rounding/c\    rounding = 15 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 10 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^\([^#]\)/#\1/' "$HYPR_CONF"
            sed -i '/@dynamic_dunst/c\    corner_radius = 15 # @dynamic_dunst' "$DUNST_CONF"

            hyprctl keyword decoration:rounding 15 > /dev/null
            hyprctl keyword decoration:rounding_power 10 > /dev/null
            hyprctl reload > /dev/null

            killall dunst && dunst &
            sleep 0.2
            notify-send "toggled" "rounded"
        else
            sed -i '/@dynamic_rounding/c\    rounding = 0 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 0 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^#//g' "$HYPR_CONF"
            sed -i '/@dynamic_dunst/c\    corner_radius = 0 # @dynamic_dunst' "$DUNST_CONF"

            hyprctl keyword decoration:rounding 0 > /dev/null
            hyprctl keyword decoration:rounding_power 0 > /dev/null
            hyprctl reload > /dev/null

            killall dunst && dunst &
            sleep 0.1
            notify-send "toggled" "sharp"
        fi
        ;;
esac
