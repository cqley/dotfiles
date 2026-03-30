#!/bin/bash

playerctl metadata --format '{{title}} - {{artist}}' --follow | while read -r line; do
    if playerctl status >/dev/null 2>&1; then
        art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)
        notify-send -i "$art_url" \
                    -h string:x-canonical-private-synchronous:media \
                    "playing" "$line"
    fi
done
