#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/x2p3lnk7tq9z/dotfiles.git"

PACMAN_PKGS=(
    hyprland
    hyprlock
    xdg-desktop-portal-hyprland
    kitty
    rofi
    dunst
    btop
    fastfetch
    fish
    imagemagick
    libnotify
    git
    base-devel
)

AUR_PKGS=(
    zed
    awww
    python-pywal16
)

install() {
    [[ $EUID -eq 0 ]] && { echo "do not run as root"; exit 1; }
    command -v git &>/dev/null || { echo "git required"; exit 1; }

    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"

    if ! command -v yay &>/dev/null; then
        tmp=$(mktemp -d)
        git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
        (cd "$tmp/yay" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    yay -S --needed --noconfirm "${AUR_PKGS[@]}"

    tmp=$(mktemp -d)
    git clone --depth=1 "$REPO_URL" "$tmp/dotfiles" &>/dev/null

    mkdir -p "$HOME/.config"

    for src in "$tmp/dotfiles/.config"/*/; do
        name="$(basename "$src")"
        [[ "$name" == "wallpaper" ]] && continue
        dst="$HOME/.config/$name"
        [[ -e "$dst" || -L "$dst" ]] && rm -rf "$dst"
        cp -r "$src" "$dst"
    done

    if [[ -d "$tmp/dotfiles/.config/scripts" ]]; then
        find "$HOME/.config/scripts" -type f | xargs chmod +x
    fi

    mkdir -p "$HOME/.config/wallpaper"
    find "$tmp/dotfiles/.config/wallpaper" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" \) ! -iname "README*" | while read -r img; do
        cp "$img" "$HOME/.config/wallpaper/"
    done

    rm -rf "$tmp"
    hyprctl reload && clear
    echo "dotfiles installed"
}

sync() {
    CONFIGS=(btop dunst fastfetch fish hypr kitty rofi scripts wallpaper zed)

    echo
    for name in "${CONFIGS[@]}"; do
        echo "$name"
    done
    echo
    read -rp "> " input </dev/tty

    tmp=$(mktemp -d)
    git clone --depth=1 "$REPO_URL" "$tmp/dotfiles" &>/dev/null

    reload_hypr=false
    synced_any=false

    for name in $input; do
        src="$tmp/dotfiles/.config/$name"
        dst="$HOME/.config/$name"

        if [[ ! -d "$src" ]]; then
            echo "unknown: $name"
            continue
        fi

        if [[ "$name" == "wallpaper" ]]; then
            mkdir -p "$dst"
            find "$src" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" \) ! -iname "README*" | while read -r img; do
                cp "$img" "$dst/"
            done
        else
            [[ -e "$dst" || -L "$dst" ]] && rm -rf "$dst"
            cp -r "$src" "$dst"
        fi

        [[ "$name" == "scripts" ]] && find "$dst" -type f | xargs chmod +x
        [[ "$name" == "hypr" ]] && reload_hypr=true
        echo "synced $name"
        synced_any=true
    done

    rm -rf "$tmp"

    $reload_hypr && hyprctl reload &>/dev/null
    $synced_any || echo "nothing synced"
}

echo "install"
echo "sync"
echo
read -rp "> " choice </dev/tty

case "$choice" in
    install) install ;;
    sync) sync ;;
    *) echo "invalid"; exit 1 ;;
esac
