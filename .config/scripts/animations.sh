#!/bin/bash

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
options="fade\nvertical\nhorizontal"

choice=$(echo -e "$options" | rofi -dmenu -i -p ">")

[[ -z "$choice" ]] && exit

case "$choice" in
    fade)
        sed -i '/@dynamic_workspaces/c\    animation = workspaces, 1, 1.94, almostLinear, fade # @dynamic_workspaces' "$HYPR_CONF"
        sed -i '/@dynamic_special/c\    animation = specialWorkspace, 1, 1.94, almostLinear, fade # @dynamic_special' "$HYPR_CONF"
        hyprctl keyword animation "workspaces, 1, 1.94, almostLinear, fade"
        hyprctl keyword animation "specialWorkspace, 1, 1.94, almostLinear, fade"
        notify-send "animations" "fade mode"
        ;;
    vertical)
        sed -i '/@dynamic_workspaces/c\    animation = workspaces, 1, 5, hard, slidevert # @dynamic_workspaces' "$HYPR_CONF"
        sed -i '/@dynamic_special/c\    animation = specialWorkspace, 1, 5, hard, slide # @dynamic_special' "$HYPR_CONF"
        hyprctl keyword animation "workspaces, 1, 5, hard, slidevert"
        hyprctl keyword animation "specialWorkspace, 1, 5, hard, slide"
        notify-send "animations" "vertical slide"
        ;;
    horizontal)
        sed -i '/@dynamic_workspaces/c\    animation = workspaces, 1, 5, hard, slide # @dynamic_workspaces' "$HYPR_CONF"
        sed -i '/@dynamic_special/c\    animation = specialWorkspace, 1, 5, hard, slidevert # @dynamic_special' "$HYPR_CONF"
        hyprctl keyword animation "workspaces, 1, 5, hard, slide"
        hyprctl keyword animation "specialWorkspace, 1, 5, hard, slidevert"
        notify-send "animations" "horizontal slide"
        ;;
esac
