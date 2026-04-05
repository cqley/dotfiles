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
    firefox
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
        [[ "$name" == "mozilla" ]] && continue
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

    xdg-mime default imv.desktop image/jpeg image/png image/gif image/webp image/bmp image/tiff
    xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/x-flv
    xdg-mime default dev.zed.Zed.desktop text/plain text/markdown text/x-shellscript text/x-python text/x-lua text/x-perl text/x-ruby text/x-yaml text/css text/html application/json application/xml text/x-csrc text/x-chdr text/x-c++src text/x-rust text/x-go
    gsettings set org.gnome.nautilus.window-state sort-column 'type'
    printf "file://$HOME/Downloads Downloads\nfile://$HOME/Documents Documents\nfile://$HOME/Pictures Pictures\nfile://$HOME/Videos Videos\nfile://$HOME/.config .config\n" > ~/.config/gtk-3.0/bookmarks
    
    pkill -x firefox && sleep 1 || true
    firefox --headless --no-remote 2>/dev/null &
    sleep 3
    pkill -x firefox || true
    sleep 1
    ff_profile=""
    for p in "$HOME/.config/mozilla/firefox/"*.default-release; do
        [[ "$(basename "$p")" == "*.default-release" ]] && continue
        [[ -d "$p" ]] && { ff_profile="$p"; break; }
    done
    if [[ -n "$ff_profile" ]]; then
        ff_src=""
        for p in "$tmp/dotfiles/.config/mozilla/firefox/"*.default-release/chrome; do
            [[ -d "$p" ]] && { ff_src="$p"; break; }
        done
        mkdir -p "$ff_profile/chrome"
        for f in userChrome.css userContent.css; do
            [[ -n "$ff_src" && -f "$ff_src/$f" ]] && cp "$ff_src/$f" "$ff_profile/chrome/$f"
        done
        grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$ff_profile/prefs.js" \
            || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$ff_profile/prefs.js"
    else
        echo "firefox profile not found"
    fi

    rm -rf "$tmp"

    hyprctl reload && clear
    echo "dotfiles installed"
}

sync() {
    CONFIGS=(btop dunst fastfetch fish firefox gtk-3.0 gtk-4.0 hypr kitty rofi scripts wallpaper zed)

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
            src=""
            for p in "$tmp/dotfiles/.config/mozilla/firefox/"*.default-release/chrome; do
                [[ -d "$p" ]] && { src="$p"; break; }
            done
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
            ff_profile=""
            for p in "$HOME/.config/mozilla/firefox/"*.default-release; do
                [[ "$(basename "$p")" == "*.default-release" ]] && continue
                [[ -d "$p" ]] && { ff_profile="$p"; break; }
            done
            if [[ -n "$ff_profile" ]]; then
                mkdir -p "$ff_profile/chrome"
                for f in userChrome.css userContent.css; do
                    [[ -f "$src/$f" ]] && cp "$src/$f" "$ff_profile/chrome/$f"
                done
                grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$ff_profile/prefs.js" \
                    || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$ff_profile/prefs.js"
            else
                echo "firefox profile not found"
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
        [[ "$name" == "gtk-3.0" ]] && printf "file://$HOME/Downloads Downloads\nfile://$HOME/Documents Documents\nfile://$HOME/Pictures Pictures\nfile://$HOME/Videos Videos\nfile://$HOME/.config .config\n" > ~/.config/gtk-3.0/bookmarks
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
