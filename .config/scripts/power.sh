#!/bin/bash

options="lock\nlogout\nshutdown\nreboot"
choice=$(echo -e "$options" | fuzzel -d -p "> ")

case "$choice" in
    lock)
        hyprlock
        ;;
    logout)
        command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit
        ;;
    shutdown)
        shutdown now
        ;;
    reboot)
        reboot
        ;;
esac
