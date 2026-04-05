#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/x2p3lnk7tq9z/dotfiles.git"

PACMAN_PKGS=(
    base-devel
    git
    fish
    hyprland
    hyprlock
    xdg-desktop-portal-hyprland
    xdg-utils
    perl-file-mimeinfo
    cliphist
    nautilus
    kitty
    rofi
    dunst
    btop
    fastfetch
    imv
    mpv
    imagemagick
    playerctl
    libnotify
)

AUR_PKGS=(
    zed
    awww
    python-pywal16
    python-pywalfox
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

    xdg-mime default imv.desktop image/jpeg image/png image/gif image/webp image/bmp image/tiff
    xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/x-flv

    pkill -x firefox && sleep 1 || true
    ff_profile=$(echo "$HOME/.config/mozilla/firefox/"*.default-release)
    if [[ -d "$ff_profile" ]]; then
        mkdir -p "$ff_profile/chrome"
        for f in userChrome.css userContent.css; do
            src="$tmp/dotfiles/.config/mozilla/firefox/chrome/$f"
            [[ -f "$src" ]] && cp "$src" "$ff_profile/chrome/$f"
        done
        grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$ff_profile/prefs.js" \
            || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$ff_profile/prefs.js"
    else
        echo "firefox not found"
    fi

    hyprctl reload && clear
    echo "dotfiles installed"
}

sync() {
    CONFIGS=(btop dunst fastfetch fish firefox hypr kitty rofi scripts wallpaper zed)

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
        if [[ "$name" == "firefox" ]]; then
            src=$(echo "$tmp/dotfiles/.config/mozilla/firefox/"*.default-release/chrome)
        else
            src="$tmp/dotfiles/.config/$name"
        fi
        dst="$HOME/.config/$name"

        if [[ "$name" != "firefox" ]] && [[ ! -d "$src" ]]; then
            echo "unknown: $name"
            continue
        fi

        if [[ "$name" == "firefox" ]]; then
            pkill -x firefox && sleep 1 || true
            ff_profile=$(echo "$HOME/.config/mozilla/firefox/"*.default-release)
            if [[ -d "$ff_profile" ]]; then
                mkdir -p "$ff_profile/chrome"
                for f in userChrome.css userContent.css; do
                    [[ -f "$src/$f" ]] && cp "$src/$f" "$ff_profile/chrome/$f"
                done
                grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$ff_profile/prefs.js" \
                    || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$ff_profile/prefs.js"
            else
                echo "firefox not found"
                continue
            fi
        elif [[ "$name" == "wallpaper" ]]; then
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
