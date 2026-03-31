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

hyprctl reload
echo "dotfiles installed"
