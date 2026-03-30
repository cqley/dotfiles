#!/bin/bash

prev_track=""

while true; do
    status=$(playerctl status 2>/dev/null | tr '[:upper:]' '[:lower:]')

    if [ "$status" = "playing" ]; then
        title=$(playerctl metadata title 2>/dev/null | tr '[:upper:]' '[:lower:]')
        artist=$(playerctl metadata artist 2>/dev/null | tr '[:upper:]' '[:lower:]')
        track="${title}${artist}"

        if [ "$track" != "$prev_track" ] && [ -n "$title" ]; then
            prev_track="$track"
            player=$(playerctl metadata --format '{{playerName}}' 2>/dev/null | tr '[:upper:]' '[:lower:]')
            player_label="${player} [hifi]"
            art_url=""
            for i in $(seq 1 10); do
                art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)
                [ -n "$art_url" ] && break
                sleep 0.1
            done

            if [ -n "$art_url" ]; then
                ext="${art_url##*.}"
                ext="${ext%%\?*}"
                art_cache="/tmp/art.${ext}"
                curl -sL --max-time 5 "$art_url" -o "$art_cache"
                notify-send \
                    -i "$art_cache" \
                    -h string:x-canonical-private-synchronous:media \
                    "${title} • ${artist}" \
                    "$player_label"
            else
                notify-send \
                    -i "audio-x-generic" \
                    -h string:x-canonical-private-synchronous:media \
                    "${title} • ${artist}" \
                    "$player_label"
            fi
        fi
    fi
done
