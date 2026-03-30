#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/x2p3lnk7tq9z/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

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
    pywal16
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

if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" pull --ff-only &>/dev/null
else
    git clone --depth=1 "$REPO_URL" "$DOTFILES_DIR" &>/dev/null
fi

mkdir -p "$HOME/.config"

for src in "$DOTFILES_DIR/.config"/*/; do
    name="$(basename "$src")"
    dst="$HOME/.config/$name"
    [[ -e "$dst" || -L "$dst" ]] && rm -rf "$dst"
    cp -r "$src" "$dst"
done

if [[ -d "$DOTFILES_DIR/.config/scripts" ]]; then
    find "$DOTFILES_DIR/.config/scripts" -type f | xargs chmod +x
fi

echo "dotfiles installed"
