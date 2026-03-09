#!/bin/bash

WALL_DIR="$HOME/.config/wallpaper"
CACHE_PATH="$HOME/.cache/current_wallpaper.png"

selected=$(echo -e "random\n$(ls "$WALL_DIR")" | fuzzel -d -p "> ")

[[ -z "$selected" ]] && exit

if [ "$selected" = "random" ]; then
    current_wall=$(basename "$(readlink -f "$CACHE_PATH")")
    selected=$(ls "$WALL_DIR" | grep -v "$current_wall" | shuf -n 1)
fi

FULL_PATH="$WALL_DIR/$selected"

swww img "$FULL_PATH" --transition-type grow --transition-duration 1.5 --transition-fps 120

wal -i "$FULL_PATH" -n -q

ln -sf "$FULL_PATH" "$CACHE_PATH"

kill -SIGUSR1 $(pgrep kitty) 2>/dev/null

killall dunst
dunst &

sleep 0.1
notify-send "theme" "updated from $selected"
