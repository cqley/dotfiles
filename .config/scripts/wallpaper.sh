#!/bin/bash

WALLPAPER_DIR="$HOME/.config/wallpaper/"
THUMBNAIL_DIR="$HOME/.cache/thumbnails/"
CACHE_PATH="$HOME/.cache/wallpaper/wallpaper.*"
RASI_THEME="$HOME/.config/rofi/wallpaper.rasi"
DUNST_CONFIG="$HOME/.config/dunst/dunstrc"
MAIN_MONITOR="HDMI-A-1"
SECOND_MONITOR="DP-1"

list_images() {
    DICE_ICON="$HOME/.config/wallpaper/dice.png"
    echo -en "random\0icon\x1f$DICE_ICON\n"

    for img in "$WALLPAPER_DIR"*; do
        filename=$(basename "$img")

        [[ "$filename" == "dice.png" ]] && continue

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
    selected=$(ls -p "$WALLPAPER_DIR" | grep -v / | grep -v "^$current_wall$" | grep -v "dice.png" | shuf -n 1)
fi

FULL_PATH="$WALLPAPER_DIR/$selected"

awww img -o "$MAIN_MONITOR" "$FULL_PATH" --transition-type grow --transition-duration 1.5 --transition-fps 120
awww clear --outputs "$SECOND_MONITOR"

wal -i "$FULL_PATH" -n -q
mkdir -p "$(dirname "$CACHE_PATH")"
ln -sf "$FULL_PATH" "$CACHE_PATH"
ln -sf ~/.cache/wal/colors-zed.json ~/.config/zed/themes/colors-zed.json

if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    source "$HOME/.cache/wal/colors.sh"
    sed -i "s/^[[:space:]]*frame_color = .*/    frame_color = \"$color4\"/" "$DUNST_CONFIG"
fi

kill -SIGUSR1 $(pgrep kitty) 2>/dev/null
killall dunst
dunst &

sleep 0.1
notify-send "theme" "updated"
