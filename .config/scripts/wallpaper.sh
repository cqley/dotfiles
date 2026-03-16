#!/bin/bash

WALLPAPER_DIR="$HOME/.config/wallpaper/"
THUMBNAIL_DIR="$HOME/.cache/wallpaper_thumbnails/"
CACHE_PATH="$HOME/.cache/wallpaper.img"
RASI_THEME="$HOME/.config/rofi/wallpaper.rasi"
MAIN_MONITOR="HDMI-A-1"
SECOND_MONITOR="DP-1"

mkdir -p "$THUMBNAIL_DIR"
list_images() {
    DICE_ICON="$HOME/.config/rofi/dice.png"
    echo -en "random\0icon\x1f$DICE_ICON\n"

    for img in "$WALLPAPER_DIR"*; do
        filename=$(basename "$img")
        thumb="$THUMBNAIL_DIR$filename"

        if [ ! -f "$thumb" ]; then
            convert "$img" -thumbnail 300x "$thumb" &
        fi

        echo -en "$filename\0icon\x1f$thumb\n"
    done
    wait
}

selected=$(list_images | rofi -dmenu -i -p ">" -theme "$RASI_THEME")

[[ -z "$selected" ]] && exit

if [[ "$selected" == "random" ]]; then
    current_wall=$(basename "$(readlink -f "$CACHE_PATH")" 2>/dev/null)
    selected=$(ls "$WALLPAPER_DIR" | grep -v "$current_wall" | shuf -n 1)
fi

FULL_PATH="$WALLPAPER_DIR/$selected"

swww img -o "$MAIN_MONITOR" "$FULL_PATH" --transition-type grow --transition-duration 1.5 --transition-fps 120
swww clear --outputs "$SECOND_MONITOR"

wal -i "$FULL_PATH" -n -q
ln -sf "$FULL_PATH" "$CACHE_PATH"

kill -SIGUSR1 $(pgrep kitty) 2>/dev/null
killall dunst
dunst &

sleep 0.1
notify-send "theme" "updated"
