#!/bin/bash
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

options="󰃟 sharp/round toggle"
choice=$(echo -e "$options" | rofi -dmenu -i -p "hyprland settings")

[[ -z "$choice" ]] && exit

case "$choice" in
    *toggle*)
        if grep -q "rounding = 0 # @dynamic_rounding" "$HYPR_CONF"; then
            sed -i '/@dynamic_rounding/c\    rounding = 15 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 10 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^\([^#]\)/#\1/' "$HYPR_CONF"

            hyprctl keyword decoration:rounding 15 > /dev/null
            hyprctl keyword decoration:rounding_power 10 > /dev/null
            hyprctl reload > /dev/null
            notify-send "toggled" "rounded"
        else
            sed -i '/@dynamic_rounding/c\    rounding = 0 # @dynamic_rounding' "$HYPR_CONF"
            sed -i '/@dynamic_power/c\    rounding_power = 0 # @dynamic_power' "$HYPR_CONF"
            sed -i '/@dynamic_smartgaps/s/^#//g' "$HYPR_CONF"

            hyprctl keyword decoration:rounding 0 > /dev/null
            hyprctl keyword decoration:rounding_power 0 > /dev/null
            hyprctl reload > /dev/null
            notify-send "toggled" "sharp"
        fi
        ;;
esac
