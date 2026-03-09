#!/bin/bash

WALL_DIR="$HOME/.config/wallpaper/"
CACHE_PATH="$HOME/.cache/wallpaper.*"
MAIN_MONITOR="HDMI-A-1"
SECOND_MONITOR="DP-1"

selected=$(echo -e "random\n$(ls "$WALL_DIR")" | fuzzel -d -p "> ")

[[ -z "$selected" ]] && exit

if [ "$selected" = "random" ]; then
    wall=$(basename "$(readlink -f "$CACHE_PATH")")
    selected=$(ls "$WALL_DIR" | grep -v "$wall" | shuf -n 1)
fi

FULL_PATH="$WALL_DIR/$selected"

swww img -o "$MAIN_MONITOR" "$FULL_PATH" --transition-type grow --transition-duration 1.5 --transition-fps 120
swww img -o "$SECOND_MONITOR" /dev/null --transition-type none 2>/dev/null

wal -i "$FULL_PATH" -n -q

ln -sf "$FULL_PATH" "$CACHE_PATH"

kill -SIGUSR1 $(pgrep kitty) 2>/dev/null

killall dunst
dunst &

sleep 0.1
notify-send "theme" "updated from $selected"
