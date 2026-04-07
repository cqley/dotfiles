#!/bin/bash

WG_DIR="/etc/wireguard"
LAST_VPN="$HOME/.cache/last_vpn"

notify() {
    notify-send -a "network" "$1" "$2" 2>/dev/null || true
}

wg_active() {
    wg show interfaces 2>/dev/null | tr ' ' '\n' | grep -v '^$'
}

wg_configs() {
    for f in "$WG_DIR"/*.conf; do
        [[ -f "$f" ]] && basename "$f" .conf
    done
}

config_prefix() {
    echo "$1" | grep -oP '^[a-z]+-[a-z]+'
}

current_ssid() {
    nmcli -t -f active,ssid dev wifi 2>/dev/null \
        | awk -F: '/^yes/{print $2}' | head -1
}

rofi_pick() {
    rofi -dmenu -p ">"
}

wg_down() {
    local iface="$1"
    sudo bash -c "
        wg-quick down '$iface' 2>/dev/null || true
        ip link delete '$iface' 2>/dev/null || true
        while ip rule del not fwmark 51820 table 51820 2>/dev/null; do :; done
        while ip rule del table main suppress_prefixlength 0 2>/dev/null; do :; done
        ip route flush table 51820 2>/dev/null || true
        while ip -6 rule del not fwmark 51820 table 51820 2>/dev/null; do :; done
        while ip -6 rule del table main suppress_prefixlength 0 2>/dev/null; do :; done
        ip -6 route flush table 51820 2>/dev/null || true
        nft delete table inet wg-quick-'$iface' 2>/dev/null || true
        resolvconf -u 2>/dev/null || true
    "
    local con
    con=$(nmcli -t -f name,type con show --active 2>/dev/null \
        | awk -F: '/wireless/{print $1}' | head -1)
    [[ -n "$con" ]] && nmcli con up "$con" 2>/dev/null
}

vpn_connect() {
    local iface="$1"
    local return_fn="$2"
    mapfile -t active < <(wg_active)
    for a in "${active[@]}"; do
        wg_down "$a"
    done
    sudo resolvconf -u 2>/dev/null
    if sudo wg-quick up "$iface"; then
        echo "$iface" > "$LAST_VPN"
        notify "vpn" "connected: $iface"
    else
        notify "vpn" "error: $iface"
        $return_fn
    fi
}

vpn_servers() {
    local location="$1"
    mapfile -t active  < <(wg_active)
    mapfile -t configs < <(wg_configs)

    local options=""
    for cfg in "${configs[@]}"; do
        [[ $(config_prefix "$cfg") != "$location" ]] && continue
        if printf '%s\n' "${active[@]}" | grep -qx "$cfg"; then
            options+="$cfg (on)\n"
        else
            options+="$cfg\n"
        fi
    done
    options+="back"

    local choice
    choice=$(echo -e "$options" | rofi_pick)
    [[ "$choice" == "back" || -z "$choice" ]] && { vpn_locations; return; }

    local iface="${choice/ (on)/}"

    if printf '%s\n' "${active[@]}" | grep -qx "$iface"; then
        if wg_down "$iface"; then
            notify "vpn" "disconnected: $iface"
        else
            notify "vpn" "error: $iface"
        fi
        vpn_servers "$location"
    else
        vpn_connect "$iface" "vpn_servers $location"
    fi
}

vpn_locations() {
    mapfile -t configs < <(wg_configs)

    declare -A seen
    local locations=""
    for cfg in "${configs[@]}"; do
        local prefix
        prefix=$(config_prefix "$cfg")
        if [[ -n "$prefix" && -z "${seen[$prefix]+x}" ]]; then
            seen[$prefix]=1
            locations+="$prefix\n"
        fi
    done
    locations+="back"

    local location
    location=$(echo -e "$locations" | rofi_pick)
    [[ "$location" == "back" || -z "$location" ]] && { vpn_menu; return; }

    vpn_servers "$location"
}

vpn_menu() {
    local active_vpn
    active_vpn=$(wg_active | head -1)

    local toggle_label
    [[ -n "$active_vpn" ]] && toggle_label="on" || toggle_label="off"

    local choice
    choice=$(printf 'locations\n%s\nback\n' "$toggle_label" | rofi_pick)

    case "$choice" in
        locations)  vpn_locations ;;
        on|off)
            if [[ -n "$active_vpn" ]]; then
                if wg_down "$active_vpn"; then
                notify "vpn" "disconnected: $active_vpn"
            else
                notify "vpn" "error: $active_vpn"
                vpn_menu
            fi
            else
                local last=""
                [[ -f "$LAST_VPN" ]] && last=$(cat "$LAST_VPN")
                if [[ -n "$last" ]]; then
                    vpn_connect "$last" vpn_menu
                else
                    notify "vpn" "no previous connection"
                    vpn_menu
                fi
            fi
            ;;
        back) main_menu ;;
    esac
}

wifi_menu() {
    local ssid
    ssid=$(current_ssid)

    local choice
    choice=$(printf 'scan\ndisconnect\nback' | rofi_pick)

    case "$choice" in
        scan)
            nmcli dev wifi rescan 2>/dev/null
            local networks
            networks=$(nmcli -t -f ssid,signal,security dev wifi list 2>/dev/null \
                | awk -F: 'NF>=1 && $1!="" {printf "%-36s  %s  %s\n", $1, $2, $3}' \
                | sort -k2 -rn | head -40)

            local picked
            picked=$(echo "$networks" | rofi_pick)
            [[ -z "$picked" ]] && { wifi_menu; return; }

            local target
            target=$(echo "$picked" | awk '{print $1}')

            if ! nmcli dev wifi connect "$target" 2>/dev/null; then
                local pass
                pass=$(rofi -dmenu -password -p "password >" < /dev/null)
                [[ -z "$pass" ]] && { wifi_menu; return; }
                nmcli dev wifi connect "$target" password "$pass" \
                    && notify "wifi" "connected: $target" \
                    || notify "wifi" "failed: $target"
            else
                notify "wifi" "connected: $target"
            fi
            wifi_menu
            ;;
        disconnect)
            local con
            con=$(nmcli -t -f name,type con show --active \
                | awk -F: '/wireless/{print $1}' | head -1)
            [[ -n "$con" ]] \
                && nmcli con down "$con" && notify "wifi" "disconnected" \
                || notify "wifi" "nothing to disconnect"
            wifi_menu
            ;;
        back) main_menu ;;
    esac
}

main_menu() {
    local ssid
    ssid=$(current_ssid)
    local active_vpn
    active_vpn=$(wg_active | head -1)

    local choice
    choice=$(printf 'wifi%s\nvpn%s\n' \
        "${ssid:+ ($ssid)}" \
        "${active_vpn:+ ($active_vpn)}" \
        | rofi_pick)

    case "$choice" in
        wifi*) wifi_menu ;;
        vpn*)  vpn_menu ;;
    esac
}

main_menu
