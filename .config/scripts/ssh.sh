#!/bin/bash

declare -A servers
servers=(
    ["servername"]="user@ip"
)

choice=$(printf "%s\n" "${!servers[@]}" | rofi -dmenu -i -p ">")

if [[ -n "$choice" ]]; then
    connection_string="${servers[$choice]}"
    kitty --detach ssh "$connection_string" &
    nautilus "sftp://$connection_string" &
fi
