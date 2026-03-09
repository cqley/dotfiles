#!/bin/bash

WALL_DIR="$HOME/.config/wallpaper"

selected=$(echo -e "random\n$(ls "$WALL_DIR")" | fuzzel -d -p "> ")

[[ -z "$selected" ]] && exit

if [ "$selected" = "random" ]; then
    selected=$(ls "$WALL_DIR" | shuf -n 1)
fi

FULL_PATH="$WALL_DIR/$selected"

swww img "$FULL_PATH" --transition-type grow --transition-duration 1.5 --transition-fps 120

wal -i "$FULL_PATH" -n -q

kill -SIGUSR1 $(pgrep kitty) 2>/dev/null

killall dunst
dunst &

sleep 0.1
notify-send "theme" "updated from $selected"
