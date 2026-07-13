{ config, pkgs, ... }:

let
  dayzDir = "${config.home.homeDirectory}/.local/share/Steam/steamapps/compatdata/221100/pfx/drive_c/users/steamuser/Documents/DayZ";
in
{
  home.packages = [ (pkgs.writeShellApplication {
    name = "meowz";
    runtimeInputs = with pkgs; [ curl jq fzf steamcmd ];
    excludeShellChecks = [ "SC2155" "SC2162" "SC2207" "SC2086" "SC2178" "SC2128" ];
    text = ''

config="$HOME/.config/dayz"
favfile="$config/favorites"
logfile="$config/last_launch.log"
steamapps="$HOME/.local/share/Steam/steamapps"
workshop="$steamapps/workshop/content/221100"
d=$'\x1f'

mkdir -p "$config"
touch "$favfile"
sed -i '/^[[:space:]]*$/d' "$favfile"
awk -F"$d" 'NF==4' "$favfile" > "$favfile.tmp" && mv "$favfile.tmp" "$favfile"

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

api() {
    curl -sg -A "mozilla" "https://api.battlemetrics.com$1"
}

fetch_servers() {
    local path="/servers?filter[game]=dayz&page[size]=100$1"
    local pages=0
    while [ -n "$path" ] && [ "$pages" -lt 4 ]; do
        local resp=$(api "$path")
        echo "$resp" | jq -e . >/dev/null 2>&1 || break
        echo "$resp" | jq -r '.data[]? | "\(.id)|\(.attributes.ip):\(.attributes.port)|\(.attributes.name) [\(.attributes.players)/\(.attributes.maxPlayers)]"'
        path=$(echo "$resp" | jq -r '.links.next // empty' | sed 's|.*battlemetrics.com||')
        pages=$((pages + 1))
    done
}

if [ "''${1:-}" = "--fetch" ]; then
    fetch_servers "''${2:+&filter[search]=$2}"
    exit 0
fi

steamuser=""
[ -f "$config/steamuser" ] && steamuser=$(cat "$config/steamuser")
if [ -z "$steamuser" ]; then
    read -p "steam username: " steamuser
    echo "$steamuser" > "$config/steamuser"
fi

steampass=""
[ -f "$config/steampass" ] && steampass=$(cat "$config/steampass")
if [ -z "$steampass" ]; then
    read -rsp "steam password (stored in plaintext, blank to skip caching): " steampass
    echo
    if [ -n "$steampass" ]; then
        (umask 177; echo "$steampass" > "$config/steampass")
    fi
fi

loginmarker="$config/steam_authenticated"

get_mods_by_id() {
    api "/servers/$1" | jq -r '.data?.attributes?.details?.modIds[]? // empty' | paste -sd, -
}

get_mods() {
    local ip="$1" port="$2"
    local m=$(curl -s "https://dayzsalauncher.com/api/v1/server/$ip:$port" | jq -r '.result?.mods[]?.steamWorkshopId // empty' | paste -sd, -)
    if [ -z "$m" ]; then
        local id=$(api "/servers?filter[game]=dayz&filter[search]=$ip:$port" | jq -r '.data[0]?.id // empty')
        [ -n "$id" ] && m=$(get_mods_by_id "$id")
    fi
    echo "$m"
}

download_mods() {
    local mods=($(echo "$1" | tr ',' '\n'))
    [ "''${#mods[@]}" -eq 0 ] && return 0

    touch "$config/blacklist"
    local missing=()
    for mod in "''${mods[@]}"; do
        grep -qx "$mod" "$config/blacklist" && continue
        find "$workshop/$mod" -mindepth 1 2>/dev/null | grep -q . || missing+=("$mod")
    done
    [ "''${#missing[@]}" -eq 0 ] && { log "mods already present"; return 0; }

    local runner="steamcmd"
    command -v steamcmd >/dev/null 2>&1 || { err "steamcmd not found"; return 1; }

    mods=("''${missing[@]}")
    local cmds=""
    for mod in "''${mods[@]}"; do
        cmds="$cmds +workshop_download_item 221100 $mod"
    done

    if pgrep -x steam >/dev/null; then
        log "closing steam..."
        steam -shutdown
        while pgrep -x steam >/dev/null; do sleep 1; done
    fi

    log "downloading mods..."
    local attempt=1
    while [ "$attempt" -le 4 ]; do
        [ "$attempt" -gt 1 ] && log "retry $attempt/4, ''${#mods[@]} mods"
        local out
        local login_args=("$steamuser")
        if [ ! -f "$loginmarker" ] && [ -n "$steampass" ]; then
            login_args=("$steamuser" "$steampass")
        fi
        out=$($runner +@sSteamCmdForcePlatformType linux -forceipv4 +login "''${login_args[@]}" $cmds +quit | tee /dev/tty) || true

        if echo "$out" | grep -q "Waiting for user info"; then
            touch "$loginmarker"
        fi
        if echo "$out" | grep -q "FAILED"; then
            rm -f "$loginmarker"
        fi

        if echo "$out" | grep -q "Invalid Password"; then
            err "wrong password, clearing cache"
            rm -f "$config/steampass"
            steampass=""
        fi

        local failed=()
        for mod in "''${mods[@]}"; do
            if echo "$out" | grep -q "Success. Downloaded item $mod "; then
                continue
            fi
            if echo "$out" | grep -qE "Download item $mod failed \((Access Denied|No match|File Not Found)\)"; then
                err "mod $mod unavailable, blacklisting"
                grep -qx "$mod" "$config/blacklist" || echo "$mod" >> "$config/blacklist"
                continue
            fi
            failed+=("$mod")
        done

        [ "''${#failed[@]}" -eq 0 ] && { log "mods downloaded"; return 0; }

        mods=("''${failed[@]}")
        cmds=""
        for mod in "''${mods[@]}"; do
            cmds="$cmds +workshop_download_item 221100 $mod"
        done
        attempt=$((attempt + 1))
        sleep 3
    done

    err "failed to download: ''${mods[*]}"
    return 1
}

launch() {
    local ip="$1" port="$2" mods="$3" mod_arg=""

    if [ -z "$ip" ] || [ -z "$port" ]; then
        err "invalid ip/port"
        return 1
    fi

    log "verifying server..."
    local verify
    verify=$(api "/servers?filter[game]=dayz&filter[search]=$ip:$port" | jq -r --arg ip "$ip" --arg port "$port" '.data[]? | select(.attributes.ip == $ip and (.attributes.port | tostring) == $port) | "\(.attributes.name) [\(.attributes.players)/\(.attributes.maxPlayers)]"' | head -n 1)
    if [ -n "$verify" ]; then
        log "found: $verify"
    else
        err "server not found on battlemetrics, connecting anyway"
    fi

    if [ -z "$mods" ]; then
        log "no mod list found, may still require mods"
    else
        log "downloading mods..."
        download_mods "$mods" || err "some mods failed, launching anyway"
        for m in $(echo "$mods" | tr ',' '\n'); do
            [ -z "$m" ] && continue
            local folder=$(find "$workshop/$m" -maxdepth 1 -type d -name "@*" 2>/dev/null | head -n 1)
            [ -z "$folder" ] && folder="$workshop/$m"
            find "$folder" -iname "*.pbo" 2>/dev/null | grep -q . || { err "missing pbo for $m, skipping"; continue; }
            mod_arg="$mod_arg;z:''${folder//\//\\}"
        done
        mod_arg="''${mod_arg#;}"
        [ -n "$mod_arg" ] && mod_arg="-mod=$mod_arg"
        sleep 3
    fi

    echo "$(date '+%F %T') connect=$ip:$port $mod_arg" >> "$logfile"

    if ! pgrep -x steam >/dev/null; then
        log "starting steam..."
        if [ ! -f "$loginmarker" ]; then
            if [ -n "$steampass" ]; then
                steam -login "$steamuser" "$steampass" >>"$config/steam.log" 2>&1 & disown
            else
                steam -login "$steamuser" >>"$config/steam.log" 2>&1 & disown
            fi
        else
            steam >>"$config/steam.log" 2>&1 & disown
        fi
        while ! pgrep -x steam >/dev/null; do sleep 1; done
        sleep 5
    fi

    log "connecting to $ip:$port..."
    if [ -n "$mod_arg" ]; then
        steam -applaunch 221100 -noLauncher "-connect=$ip" "-port=$port" "$mod_arg" >>"$config/steam.log" 2>&1
    else
        steam -applaunch 221100 -noLauncher "-connect=$ip" "-port=$port" >>"$config/steam.log" 2>&1
    fi
}

pick_server() {
    fzf --prompt="server> " --delimiter="|" --with-nth=3.. --layout=reverse \
        --disabled --ansi \
        --bind "start:reload:$0 --fetch" \
        --bind "change:reload:sleep 0.4; $0 --fetch {q}"
}

save_favorite() {
    local ip="$1" port="$2" name="$3"
    if grep -qF "$ip$d$port$d" "$favfile"; then
        err "already saved"
        return
    fi
    local mods=$(get_mods "$ip" "$port")
    printf "%s%s%s%s%s%s%s\n" "$ip" "$d" "$port" "$d" "$mods" "$d" "$name" >> "$favfile"
    log "saved $name"
}

show_favorites() {
    grep -vE '^[[:space:]]*$' "$favfile" | fzf --prompt="fav> " --delimiter="$d" --with-nth=4 --layout=reverse
}

while true; do
    action=$(printf "favorites\nbrowse\nadd manual\nremove\nrefresh mods\nquit\n" | fzf --prompt="dayz> " --layout=reverse)

    case "$action" in
        browse)
            selection=$(pick_server)
            [ -z "$selection" ] && continue
            id=$(echo "$selection" | cut -d'|' -f1)
            ip_port=$(echo "$selection" | cut -d'|' -f2)
            name=$(echo "$selection" | cut -d'|' -f3- | sed 's/ \[[0-9]*\/[0-9]*\]$//')
            ip=''${ip_port%%:*}
            port=''${ip_port##*:}
            confirm=$(printf "play\nsave to favorites\n" | fzf --prompt="$name> " --layout=reverse)
            case "$confirm" in
                play) mods=$(get_mods_by_id "$id"); launch "$ip" "$port" "$mods"; exit 0 ;;
                "save to favorites") save_favorite "$ip" "$port" "$name"; show_favorites ;;
            esac
            ;;
        favorites)
            selection=$(show_favorites)
            [ -z "$selection" ] && continue
            ip=$(echo "$selection" | cut -d"$d" -f1)
            port=$(echo "$selection" | cut -d"$d" -f2)
            mods=$(echo "$selection" | cut -d"$d" -f3)
            launch "$ip" "$port" "$mods"
            exit 0
            ;;
        "add manual")
            read -p "ip: " ip
            read -p "port: " port
            read -p "name: " name
            save_favorite "$ip" "$port" "$name"
            show_favorites
            ;;
        remove)
            selection=$(show_favorites)
            [ -z "$selection" ] && continue
            grep -vF "$selection" "$favfile" | grep -vE '^[[:space:]]*$' > "$favfile.tmp" && mv "$favfile.tmp" "$favfile"
            show_favorites
            ;;
        "refresh mods")
            selection=$(show_favorites)
            [ -z "$selection" ] && continue
            ip=$(echo "$selection" | cut -d"$d" -f1)
            port=$(echo "$selection" | cut -d"$d" -f2)
            name=$(echo "$selection" | cut -d"$d" -f4)
            mods=$(get_mods "$ip" "$port")
            grep -vF "$selection" "$favfile" | grep -vE '^[[:space:]]*$' > "$favfile.tmp" && mv "$favfile.tmp" "$favfile"
            printf "%s%s%s%s%s%s%s\n" "$ip" "$d" "$port" "$d" "$mods" "$d" "$name" >> "$favfile"
            show_favorites
            ;;
        quit|"") break ;;
    esac
done
    '';
  }) ];

  xdg.desktopEntries.meowz = {
    name = "MeowZ";
    comment = "dayz server launcher";
    exec = "kitty --hold -e meowz";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" ];
  };

  home.file."${dayzDir}/DayZ.cfg".text = ''
    language="English";
    adapter=-1;
    3D_Performance=57692;
    Resolution_Bpp=32;
    WinX=0;
    WinY=0;
    WindowWidth=1920;
    WindowHeight=1080;
    MSAA=0;
    PostFX=0;
    VSync=1;
    FXAO=0;
    AToC=0;
    AnisoFilter=4;
    TerrainDetail=2;
    FXAA=0;
    refreshMode=200;
    maxGPUToRenderFrames=1;
  '';

  home.file."${dayzDir}/steamuser_settings.DayZProfile".text = ''
    version=1;
    blood=1;
    singleVoice=0;
    gamma=1;
    lastMPServer="";
    lastMPServerName="";
    lastMPMission="";
    inputVersion=1;
    perspective=1;
    trackIR=1;
    freeTrack=1;
    mouseSmoothing=0;
    maxSamplesPlayed=96;
    vonInputMode=0;
    TexQuality=1;
    WaterQuality=1;
    tripleHead=0;
    showTitles=1;
    vehicleFreelook=0;
    pauseMode=0;
    shadowQuality=1;
    headBob=0;
    fov=0.95993;
    sceneComplexity=150000;
    shadowZDistance=80;
    viewDistance=1200;
    preferredObjectViewDistance=1200;
    terrainGrid=12.5;
    volumeMaster=5;
    volumeCD=0.5;
    volumeFX=4;
    volumeSpeech=5;
    volumeVoN=10;
    vonRecThreshold=0.029999999;
    brightness=1;
    uiTopLeftX=0.12500001;
    uiTopLeftY=0;
    uiBottomRightX=0.875;
    uiBottomRightY=1;
    IGUIScale=0.55000001;
    showHUD=1;
    hudBrightness=1.0;
    showCrosshair=0;
    showQuickbar=1;
    showVehicleHUD=1;
    showServerInfo=0;
  '';

  home.file."${dayzDir}/steamuser.dayz_preset_User.xml".text = ''
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<preset>
    <input name="UAMoveForward">
        <btn name="kW" />
        <btn name="x1LeftThumbUp" />
    </input>
    <input name="UAMoveBack">
        <btn name="kS" />
        <btn name="x1LeftThumbDown" />
    </input>
    <input name="UAMoveLeft">
        <btn name="kA" />
        <btn name="x1LeftThumbLeft" />
    </input>
    <input name="UAMoveRight">
        <btn name="kD" />
        <btn name="x1LeftThumbRight" />
    </input>
    <input name="UATurbo">
        <btn name="kLShift" />
    </input>
    <input name="UAWalkRunTemp">
        <btn name="kLControl" />
    </input>
    <input name="UAWalkRunToggle">
        <btn name="kLControl">
            <event name="doubleclick" />
        </btn>
    </input>
    <input name="UAToggleTurbo">
        <btn name="x1ThumbLeft" />
    </input>
    <input name="UAWalkForward">
        <btn name="x1LeftThumbUp" />
    </input>
    <input name="UAWalkBack">
        <btn name="x1LeftThumbDown" />
    </input>
    <input name="UAWalkLeft">
        <btn name="x1LeftThumbLeft" />
    </input>
    <input name="UAWalkRight">
        <btn name="x1LeftThumbRight" />
    </input>
    <input name="UAGetOver">
        <btn name="kSpace" />
        <btn name="x1A">
            <event name="clickorhold" />
        </btn>
    </input>
    <input name="UAGetOverControllerHelper">
        <btn name="x1A">
            <event name="clickorhold" />
        </btn>
    </input>
    <input name="UAStance">
        <btn name="x1B" />
    </input>
    <input name="UALeanLeft">
        <btn name="mB5" />
    </input>
    <input name="UALeanRight">
        <btn name="mB4" />
    </input>
    <input name="UALeanLeftGamepad">
        <btn name="x1ShoulderLeft" />
    </input>
    <input name="UALeanRightGamepad">
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UAPersonCamSwitchSide">
        <btn name="x1ThumbRight">
            <event name="holdbegin" />
        </btn>
    </input>
    <input name="UAAimLeft">
        <btn name="mLeft" />
        <btn name="x1RightThumbLeft" />
    </input>
    <input name="UAAimRight">
        <btn name="mRight" />
        <btn name="x1RightThumbRight" />
    </input>
    <input name="UAAimUp">
        <btn name="mUp" />
        <btn name="x1RightThumbUp" />
    </input>
    <input name="UAAimDown">
        <btn name="mDown" />
        <btn name="x1RightThumbDown" />
    </input>
    <input name="UATrackLeft">
        <btn name="irYawLeft" />
    </input>
    <input name="UATrackRight">
        <btn name="irYawRight" />
    </input>
    <input name="UATrackUp">
        <btn name="irPitchUp" />
    </input>
    <input name="UATrackDown">
        <btn name="irPitchDown" />
    </input>
    <input name="UAPersonView">
        <btn name="x1ThumbRight" />
        <btn name="kB" />
    </input>
    <input name="UALookAround">
        <btn name="kLMenu" />
        <btn name="x1ShoulderLeft">
            <event name="hold" />
        </btn>
    </input>
    <input name="UALookAroundToggle">
        <btn name="kLMenu">
            <event name="doubleclick" />
        </btn>
    </input>
    <input name="UAZoomIn">
        <btn name="mBMiddle" />
    </input>
    <input name="UAZoomInToggle">
        <btn name="x1ShoulderLeft">
            <event name="doubleclick" />
        </btn>
    </input>
    <input name="UAToggleNVG">
        <btn name="kL">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAToggleHeadlight">
        <btn name="kL" />
        <btn name="x1Y" />
    </input>
    <input name="UAADSToggle">
        <btn name="kLShift">
            <event name="click" />
        </btn>
        <btn name="x1ThumbRight">
            <event name="click" />
        </btn>
    </input>
    <input name="UAZoomInOptics">
        <btn name="mWheelUp" />
        <btn name="x1PadRight">
            <event name="click" />
        </btn>
    </input>
    <input name="UAZoomOutOptics">
        <btn name="mWheelDown" />
        <btn name="x1PadRight">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAZoomInOpticsControllerHelper">
        <btn name="x1PadRight">
            <event name="click" />
        </btn>
    </input>
    <input name="UAZoomOutOpticsControllerHelper">
        <btn name="x1PadRight">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAThrowitem">
        <btn name="kG">
            <event name="click" />
        </btn>
        <btn name="x1X">
            <event name="doubleclick" />
        </btn>
    </input>
    <input name="UADropitem">
        <btn name="kG">
            <event name="hold" />
        </btn>
        <btn name="x1X">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAGear">
        <btn name="kTab" />
        <btn name="x1View" />
    </input>
    <input name="UAFire">
        <btn name="mBLeft" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAHeavyMeleeAttack">
        <btn name="x1Y" />
    </input>
    <input name="UAMeleeAttackModifier">
        <btn name="kLShift" />
    </input>
    <input name="UAWeaponMeleeAttack">
        <btn name="kF" />
        <btn name="x1X" />
    </input>
    <input name="UAHoldBreath">
        <btn name="kLControl" />
        <btn name="x1ThumbLeft" />
    </input>
    <input name="UADefaultAction">
        <btn name="mBLeft" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAAction">
        <btn name="kF" />
        <btn name="x1X" />
    </input>
    <input name="UAPrevAction">
        <btn name="mWheelUp" />
        <btn name="x1PadDown">
            <event name="click" />
        </btn>
    </input>
    <input name="UANextAction">
        <btn name="mWheelDown" />
        <btn name="x1PadUp">
            <event name="click" />
        </btn>
    </input>
    <input name="UATempRaiseWeapon">
        <btn name="mBRight" />
    </input>
    <input name="UATempRaiseWeaponGamepad">
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UAReloadMagazine">
        <btn name="kR" />
        <btn name="x1Y" />
    </input>
    <input name="UAZeroingUp">
        <btn name="x1PadUp" />
        <btn name="kPrior" />
    </input>
    <input name="UAZeroingDown">
        <btn name="x1PadDown" />
        <btn name="kNext" />
    </input>
    <input name="UAToggleWeapons">
        <btn name="kX" />
        <btn name="x1A">
            <btn name="x1TriggerLeft" />
        </btn>
    </input>
    <input name="UAUIQuickbarToggle">
        <btn name="kGrave" />
    </input>
    <input name="UAItem0">
        <btn name="k1" />
    </input>
    <input name="UAItem1">
        <btn name="k2" />
    </input>
    <input name="UAItem2">
        <btn name="k3" />
    </input>
    <input name="UAItem3">
        <btn name="k4" />
    </input>
    <input name="UAItem4">
        <btn name="k5" />
    </input>
    <input name="UAItem5">
        <btn name="k6" />
    </input>
    <input name="UAItem6">
        <btn name="k7" />
    </input>
    <input name="UAItem7">
        <btn name="k8" />
    </input>
    <input name="UAItem8">
        <btn name="k9" />
    </input>
    <input name="UAItem9">
        <btn name="k0" />
    </input>
    <input name="UAChat">
        <btn name="kReturn" />
    </input>
    <input name="UAVoiceOverNet">
        <btn name="kCapital">
            <event name="hold" />
        </btn>
        <btn name="x1PadLeft">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAVoiceOverNetToggle">
        <btn name="kCapital">
            <event name="doubleclick" />
        </btn>
        <btn name="x1PadLeft">
            <event name="doubleclick" />
        </btn>
    </input>
    <input name="UAVoiceLevel">
        <btn name="kUp" />
        <btn name="x1PadLeft">
            <event name="click" />
        </btn>
    </input>
    <input name="UAVoiceDistanceUp">
        <btn name="kUp" />
        <btn name="x1ShoulderRight">
            <btn name="x1PadLeft" />
        </btn>
    </input>
    <input name="UAVoiceDistanceDown">
        <btn name="kDown" />
        <btn name="x1ShoulderLeft">
            <btn name="x1PadLeft" />
        </btn>
    </input>
    <input name="UAVoiceModifierHelper">
        <btn name="x1PadLeft" />
    </input>
    <input name="UAGestureSlot01">
        <btn name="kF1" />
    </input>
    <input name="UAGestureSlot02">
        <btn name="kF2" />
    </input>
    <input name="UAGestureSlot03">
        <btn name="kF3" />
    </input>
    <input name="UAGestureSlot04">
        <btn name="kF4" />
    </input>
    <input name="UAGestureSlot05">
        <btn name="kF5" />
    </input>
    <input name="UAGestureSlot06">
        <btn name="kF6" />
    </input>
    <input name="UAGestureSlot07">
        <btn name="kF7" />
    </input>
    <input name="UAGestureSlot08">
        <btn name="kF8" />
    </input>
    <input name="UAGestureSlot09">
        <btn name="kF9" />
    </input>
    <input name="UAGestureSlot10">
        <btn name="kF10" />
    </input>
    <input name="UAGestureSlot11">
        <btn name="kF11" />
    </input>
    <input name="EmoteGreeting">
        <btn name="kF1" />
    </input>
    <input name="EmoteSOS">
        <btn name="kF2" />
    </input>
    <input name="EmoteHeart">
        <btn name="kF3" />
    </input>
    <input name="EmoteTaunt">
        <btn name="kF4" />
    </input>
    <input name="EmoteLyingDown" />
    <input name="EmoteTauntKiss">
        <btn name="kF6" />
    </input>
    <input name="EmotePoint">
        <btn name="kF7" />
    </input>
    <input name="EmoteTauntElbow">
        <btn name="kF8" />
    </input>
    <input name="EmoteThumb">
        <btn name="kF9" />
    </input>
    <input name="EmoteThumbDown" />
    <input name="EmoteThroat">
        <btn name="kF10" />
    </input>
    <input name="EmoteDance" />
    <input name="EmoteSalute" />
    <input name="EmoteTimeout" />
    <input name="EmoteFacepalm" />
    <input name="EmoteClap" />
    <input name="EmoteSilent" />
    <input name="EmoteWatching" />
    <input name="EmoteHold" />
    <input name="EmoteListening" />
    <input name="EmotePointSelf" />
    <input name="EmoteLookAtMe" />
    <input name="EmoteTauntThink" />
    <input name="EmoteMove" />
    <input name="EmoteGetDown" />
    <input name="EmoteCome" />
    <input name="EmoteSurrender">
        <btn name="kF5" />
    </input>
    <input name="EmoteCampfireSit" />
    <input name="EmoteSitA" />
    <input name="EmoteSitB" />
    <input name="EmoteRPSRandom" />
    <input name="EmoteRPSRock" />
    <input name="EmoteRPSPaper" />
    <input name="EmoteRPSScisors" />
    <input name="EmoteNod" />
    <input name="EmoteShake" />
    <input name="EmoteShrug" />
    <input name="EmoteSuicide">
        <btn name="kF11" />
    </input>
    <input name="EmoteVomit" />
    <input name="UACarLeft">
        <btn name="kA" />
        <btn name="x1LeftThumbLeft" />
    </input>
    <input name="UACarRight">
        <btn name="kD" />
        <btn name="x1LeftThumbRight" />
    </input>
    <input name="UACarForward">
        <btn name="kW" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UACarBack">
        <btn name="kS" />
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UACarShiftGearUp">
        <btn name="kE" />
        <btn name="x1B" />
    </input>
    <input name="UACarShiftGearDown">
        <btn name="kQ" />
        <btn name="x1A" />
    </input>
    <input name="UAVehicleTurbo">
        <btn name="kLShift" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAVehicleSlow">
        <btn name="kLControl" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UACarHorn">
        <btn name="kH" />
        <btn name="x1ThumbLeft" />
    </input>
    <input name="UACarHandbrake">
        <btn name="kSpace" />
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UAUILeft">
        <btn name="kLeft" />
        <btn name="x1PadLeft" />
        <btn name="x1LeftThumbLeft" />
        <btn name="x1RightThumbLeft" />
    </input>
    <input name="UAUIRight">
        <btn name="kRight" />
        <btn name="x1PadRight" />
        <btn name="x1LeftThumbRight" />
        <btn name="x1RightThumbRight" />
    </input>
    <input name="UAUIUp">
        <btn name="kUp" />
        <btn name="x1PadUp" />
        <btn name="x1LeftThumbUp" />
        <btn name="x1RightThumbUp" />
    </input>
    <input name="UAUIDown">
        <btn name="kDown" />
        <btn name="x1PadDown" />
        <btn name="x1LeftThumbDown" />
        <btn name="x1RightThumbDown" />
    </input>
    <input name="UAUISelect">
        <btn name="kReturn" />
        <btn name="kNumpadEnter" />
        <btn name="x1A" />
    </input>
    <input name="UAUIBack">
        <btn name="kEscape" />
        <btn name="x1B">
            <event name="click" />
        </btn>
    </input>
    <input name="UAMenuSelect">
        <btn name="mBLeft" />
    </input>
    <input name="UAMenuBack">
        <btn name="mBRight" />
    </input>
    <input name="UAUICtrlX">
        <btn name="x1X" />
    </input>
    <input name="UAUICtrlY">
        <btn name="x1Y" />
    </input>
    <input name="UAUIMenu">
        <btn name="kEscape" />
        <btn name="x1Menu" />
    </input>
    <input name="UAUITabLeft">
        <btn name="kLBracket" />
        <btn name="x1ShoulderLeft" />
    </input>
    <input name="UAUITabRight">
        <btn name="kRBracket" />
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UAUICredits">
        <btn name="x1View" />
    </input>
    <input name="UAUICopyDebugMonitorPos">
        <btn name="kP" />
    </input>
    <input name="UAUIThumbRight">
        <btn name="x1ThumbRight" />
    </input>
    <input name="UAUIPadLeft">
        <btn name="x1PadLeft" />
    </input>
    <input name="UAUIPadRight">
        <btn name="x1PadRight" />
    </input>
    <input name="UAUIRightStickHorizontal">
        <btn name="x1RightThumbHorizontal" />
    </input>
    <input name="UAUIRightStickVertical">
        <btn name="x1RightThumbVertical" />
    </input>
    <input name="UAUIGesturesOpen">
        <btn name="kPeriod" />
        <btn name="x1PadRight" />
    </input>
    <input name="UAUIQuickbarRadialOpen">
        <btn name="kComma" />
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UAUIQuickbarRadialInventoryOpen">
        <btn name="kComma" />
        <btn name="x1ThumbLeft" />
    </input>
    <input name="UAUIRadialMenuStickHelper">
        <btn name="x1ThumbRight" />
    </input>
    <input name="UAUILeftInventory">
        <btn name="x1PadLeft" />
        <btn name="x1RightThumbLeft" />
    </input>
    <input name="UAUIRightInventory">
        <btn name="x1PadRight" />
        <btn name="x1RightThumbRight" />
    </input>
    <input name="UAUIUpInventory">
        <btn name="x1PadUp" />
        <btn name="x1RightThumbUp" />
    </input>
    <input name="UAUIDownInventory">
        <btn name="x1PadDown" />
        <btn name="x1RightThumbDown" />
    </input>
    <input name="UAUINextUp">
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UAUINextDown">
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAUIInventoryContainerUp">
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UAUIInventoryContainerDown">
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAUIInventoryTabLeft">
        <btn name="kLBracket" />
        <btn name="x1ShoulderLeft" />
    </input>
    <input name="UAUIInventoryTabRight">
        <btn name="kRBracket" />
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UAUIRotateInventory">
        <btn name="kSpace" />
    </input>
    <input name="UAUIFastEquip">
        <btn name="x1Y">
            <event name="click" />
        </btn>
    </input>
    <input name="UAUIPutInHandsFromVicinity">
        <btn name="x1A">
            <event name="click" />
        </btn>
    </input>
    <input name="UAUIPutInHandsFromInventory">
        <btn name="x1A">
            <event name="click" />
        </btn>
    </input>
    <input name="UAUISplit">
        <btn name="x1Y">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAUICombine">
        <btn name="x1B">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAUIDragNDrop">
        <btn name="kReturn" />
        <btn name="kNumpadEnter" />
        <btn name="x1A" />
    </input>
    <input name="UAUIFastTransferToVicinity">
        <btn name="x1X">
            <event name="hold" />
        </btn>
    </input>
    <input name="UAUIExpandCollapseContainer">
        <btn name="x1ThumbRight">
            <event name="click" />
        </btn>
    </input>
    <input name="UAUISelectItem">
        <btn name="x1A" />
    </input>
    <input name="UAUIFastTransferItem">
        <btn name="x1X">
            <event name="click" />
        </btn>
    </input>
    <input name="UAMapToggle">
        <btn name="kM" />
    </input>
    <input name="UAMapMovementHorizontal">
        <btn name="x1LeftThumbHorizontal" />
    </input>
    <input name="UAMapMovementVertical">
        <btn name="x1LeftThumbVertical" />
    </input>
    <input name="UAMapZoom">
        <btn name="x1RightThumbVertical" />
    </input>
    <input name="UASwitchPreset">
        <btn name="x1Y" />
    </input>
    <input name="UAMoveUp">
        <btn name="kQ" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UAMoveDown">
        <btn name="kZ" />
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UABuldResetCamera">
        <btn name="kNumpad0" />
    </input>
    <input name="UABuldTurbo">
        <btn name="kU" />
    </input>
    <input name="UABuldSlow">
        <btn name="kJ" />
    </input>
    <input name="UABuldFreeLook">
        <btn name="kNumpad5" />
    </input>
    <input name="UABuldRunScript">
        <btn name="kF10" />
    </input>
    <input name="UABuldSelectToggle">
        <btn name="kSpace" />
    </input>
    <input name="UABuldSelect">
        <btn name="mBLeft" />
    </input>
    <input name="UABuldSelectAddMod">
        <btn name="k7" />
    </input>
    <input name="UABuldSelectRemoveMod">
        <btn name="k8" />
    </input>
    <input name="UABuldModifySelected">
        <btn name="mBRight" />
    </input>
    <input name="UABuldCycleMod">
        <btn name="k5" />
    </input>
    <input name="UABuldRotationXAxisMod">
        <btn name="k1" />
    </input>
    <input name="UABuldRotationZAxisMod">
        <btn name="k3" />
    </input>
    <input name="UABuldCoordModCycle">
        <btn name="k6" />
    </input>
    <input name="UABuldSampleTerrainHeight">
        <btn name="mBRight" />
    </input>
    <input name="UABuldSetTerrainHeight">
        <btn name="mBLeft" />
    </input>
    <input name="UABuldScaleMod">
        <btn name="kE" />
    </input>
    <input name="UABuldElevateMod">
        <btn name="kT" />
    </input>
    <input name="UABuldSmoothMod">
        <btn name="kLShift" />
    </input>
    <input name="UABuldFlattenMod">
        <btn name="kLMenu" />
    </input>
    <input name="UABuldBrushRatioUp">
        <btn name="kB">
            <btn name="mWheelUp" />
        </btn>
    </input>
    <input name="UABuldBrushRatioDown">
        <btn name="kB">
            <btn name="mWheelDown" />
        </btn>
    </input>
    <input name="UABuldBrushOuterUp">
        <btn name="kN">
            <btn name="mWheelUp" />
        </btn>
    </input>
    <input name="UABuldBrushOuterDown">
        <btn name="kN">
            <btn name="mWheelDown" />
        </btn>
    </input>
    <input name="UABuldBrushStrengthUp">
        <btn name="kM">
            <btn name="mWheelUp" />
        </btn>
    </input>
    <input name="UABuldBrushStrengthDown">
        <btn name="kM">
            <btn name="mWheelDown" />
        </btn>
    </input>
    <input name="UABuldToggleNearestObjectArrow">
        <btn name="kH" />
    </input>
    <input name="UABuldCycleBrushMod">
        <btn name="kG" />
    </input>
    <input name="UABuldSelectionType">
        <btn name="kF" />
    </input>
    <input name="UABuldCreateLastSelectedObject">
        <btn name="kV" />
    </input>
    <input name="UABuldDuplicateSelection">
        <btn name="kC" />
    </input>
    <input name="UABuldDeleteSelection">
        <btn name="kR" />
    </input>
    <input name="UABuldUndo">
        <btn name="kLControl">
            <btn name="kX" />
        </btn>
    </input>
    <input name="UABuldRedo">
        <btn name="kLControl">
            <btn name="kY" />
        </btn>
    </input>
    <input name="UABuldMoveLeft">
        <btn name="mLeft" />
        <btn name="kA" />
    </input>
    <input name="UABuldMoveRight">
        <btn name="mRight" />
        <btn name="kD" />
    </input>
    <input name="UABuldMoveForward">
        <btn name="mUp" />
        <btn name="kW" />
    </input>
    <input name="UABuldMoveBack">
        <btn name="mDown" />
        <btn name="kS" />
    </input>
    <input name="UABuldMoveUp">
        <btn name="kQ" />
    </input>
    <input name="UABuldMoveDown">
        <btn name="kZ" />
    </input>
    <input name="UABuldLeft">
        <btn name="kLeft" />
    </input>
    <input name="UABuldRight">
        <btn name="kRight" />
    </input>
    <input name="UABuldForward">
        <btn name="kUp" />
    </input>
    <input name="UABuldBack">
        <btn name="kDown" />
    </input>
    <input name="UABuldLookLeft">
        <btn name="kNumpad4" />
    </input>
    <input name="UABuldLookRight">
        <btn name="kNumpad6" />
    </input>
    <input name="UABuldLookUp">
        <btn name="kNumpad8" />
    </input>
    <input name="UABuldLookDown">
        <btn name="kNumpad2" />
    </input>
    <input name="UABuldZoomIn">
        <btn name="kAdd" />
    </input>
    <input name="UABuldZoomOut">
        <btn name="kSubstract" />
    </input>
    <input name="UABuldTextureInfo">
        <btn name="kI" />
    </input>
    <input name="UABuldObjectRotateLeft">
        <btn name="kNumpad4" />
        <btn name="mBLeft">
            <btn name="mLeft" />
        </btn>
    </input>
    <input name="UABuldObjectRotateRight">
        <btn name="kNumpad6" />
        <btn name="mBLeft">
            <btn name="mRight" />
        </btn>
    </input>
    <input name="UABuldObjectRotateForward">
        <btn name="kNumpad8" />
        <btn name="mBLeft">
            <btn name="mUp" />
        </btn>
    </input>
    <input name="UABuldObjectRotateBack">
        <btn name="kNumpad2" />
        <btn name="mBLeft">
            <btn name="mDown" />
        </btn>
    </input>
    <input name="UABuldViewerMoveLeft">
        <btn name="kA" />
        <btn name="mBRight">
            <btn name="mLeft" />
        </btn>
    </input>
    <input name="UABuldViewerMoveRight">
        <btn name="kD" />
        <btn name="mBRight">
            <btn name="mRight" />
        </btn>
    </input>
    <input name="UABuldViewerMoveForward">
        <btn name="kW" />
        <btn name="mBRight">
            <btn name="mUp" />
        </btn>
    </input>
    <input name="UABuldViewerMoveBack">
        <btn name="kS" />
        <btn name="mBRight">
            <btn name="mDown" />
        </btn>
    </input>
    <input name="UABuldViewerMoveUp">
        <btn name="kQ" />
    </input>
    <input name="UABuldViewerMoveDown">
        <btn name="kZ" />
    </input>
    <input name="UABuldPreviousAnimation">
        <btn name="kPrior" />
        <btn name="kLBracket" />
    </input>
    <input name="UABuldNextAnimation">
        <btn name="kNext" />
        <btn name="kRBracket" />
    </input>
    <input name="UABuldRecedeAnimation">
        <btn name="mWheelUp" />
        <btn name="kSemicolon" />
    </input>
    <input name="UABuldAdvanceAnimation">
        <btn name="mWheelDown" />
        <btn name="kApostrophe" />
    </input>
    <input name="UABuldAlignToTerrain">
        <btn name="k9" />
    </input>
    <input name="UAStand">
        <btn name="kE" />
    </input>
    <input name="UACrouch">
        <btn name="kC" />
    </input>
    <input name="UAProne">
        <btn name="kV" />
    </input>
    <input name="UABBPRotate">
        <btn name="kUp" />
    </input>
    <input name="UACycleSize">
        <btn name="kLeft" />
    </input>
    <input name="UANextSnap">
        <btn name="mWheelUp" />
    </input>
    <input name="UAPrevSnap">
        <btn name="mWheelDown" />
    </input>
    <input name="UASnapLook">
        <btn name="kDown" />
    </input>
    <input name="UABBPTogInv" />
    <input name="UASIBHeliForward">
        <btn name="kW" />
        <btn name="x1LeftThumbUp" />
    </input>
    <input name="UASIBHeliCyclicLeft">
        <btn name="kA" />
        <btn name="x1LeftThumbLeft" />
    </input>
    <input name="UASIBHeliBack">
        <btn name="kS" />
        <btn name="x1LeftThumbDown" />
    </input>
    <input name="UASIBHeliCyclicRight">
        <btn name="kD" />
        <btn name="x1LeftThumbRight" />
    </input>
    <input name="UASIBHeliForwardM">
        <btn name="mDown" />
        <btn name="x1RightThumbDown" />
    </input>
    <input name="UASIBHeliBackM">
        <btn name="mUp" />
        <btn name="x1RightThumbUp" />
    </input>
    <input name="UASIBHeliLeftM">
        <btn name="mLeft" />
        <btn name="x1RightThumbLeft" />
    </input>
    <input name="UASIBHeliRightM">
        <btn name="mRight" />
        <btn name="x1RightThumbRight" />
    </input>
    <input name="UASIBHeliEngine_new">
        <btn name="kC" />
        <btn name="x1B" />
    </input>
    <input name="UASIBHeliAutopilot">
        <btn name="mBRight" />
        <btn name="x1Y" />
    </input>
    <input name="UASIBHeliHide">
        <btn name="kX" />
        <btn name="x1X" />
    </input>
    <input name="UASIBHeliLeft">
        <btn name="kQ" />
        <btn name="x1ShoulderLeft" />
    </input>
    <input name="UASIBHeliRight">
        <btn name="kE" />
        <btn name="x1ShoulderRight" />
    </input>
    <input name="UASIBHeliUp">
        <btn name="kLShift" />
        <btn name="x1TriggerRight" />
    </input>
    <input name="UASIBHeliDown">
        <btn name="kZ" />
        <btn name="x1TriggerLeft" />
    </input>
    <input name="UABetterInspect">
        <btn name="kB" />
    </input>
    <input name="UALBAdminMenuToggle">
        <btn name="kU" />
    </input>
    <input name="UALBAdminMenuOpen">
        <btn name="kI" />
    </input>
    <input name="UALBMEarPlugsToggle">
        <btn name="kN" />
    </input>
    <input name="UALBMEarPlugsLouder">
        <btn name="kEquals" />
    </input>
    <input name="UALBMEarPlugsQuieter">
        <btn name="kMinus" />
    </input>
    <input name="UALBMGroupOpenMap">
        <btn name="kM" />
    </input>
    <input name="UALBMGroupOpenMapGroup">
        <btn name="kP" />
    </input>
    <input name="UALBMGroupTacticalPing">
        <btn name="kT" />
    </input>
    <input name="UALBMGroupTacticalPingClear">
        <btn name="kC" />
    </input>
    <input name="UALBMGroupDeleteMarker">
        <btn name="kDelete" />
    </input>
    <input name="UALBMGroupToggleVisibility">
        <btn name="kK" />
    </input>
    <input name="UALBMSwitchChatChannel">
        <btn name="kComma" />
    </input>
    <input name="UALBMGroupToggleCompass">
        <btn name="kH" />
    </input>
    <input name="UALBMGroupTogglePlayerList">
        <btn name="kU" />
    </input>
    <input name="UALBMGroupToggleMiniMap">
        <btn name="kB" />
    </input>
    <input name="UALBMGroupAcceptInvite">
        <btn name="kLControl">
            <btn name="kJ" />
        </btn>
        <btn name="kRControl">
            <btn name="kJ" />
        </btn>
    </input>
    <input name="UALBMHoverLoot">
        <btn name="k0" />
    </input>
    <input name="UALBMOpenRestrictions">
        <btn name="kLControl">
            <btn name="kR" />
        </btn>
    </input>
    <input name="Loaded_ToggleVisor">
        <btn name="kL" />
    </input>
    <input name="UASchanaAutorunToggle">
        <btn name="kF10" />
    </input>
    <input name="UATogglePlayerControls">
        <btn name="kSpace" />
    </input>
    <input name="UAHealTargets">
        <btn name="kJ" />
    </input>
    <input name="UAToggleFreeCam">
        <btn name="kBackspace" />
    </input>
    <input name="UACopyPositionClipboard">
        <btn name="kP" />
    </input>
    <input name="UARepairVehicleAtCrosshairs">
        <btn name="kK" />
    </input>
    <input name="UAFocusOnGame">
        <btn name="kTab" />
    </input>
    <input name="UACollapseESPDropDwn" />
    <input name="UATogglePlayerDetailEsp" />
    <input name="UAExitSpectate">
        <btn name="kPrior" />
    </input>
    <input name="UASelectObject">
        <btn name="mBLeft" />
    </input>
    <input name="UADeSelectObject">
        <btn name="kLControl" />
    </input>
    <input name="UAExecuteCommand">
        <btn name="kReturn" />
        <btn name="kNumpadEnter" />
    </input>
    <input name="UAUPCommand">
        <btn name="kUp" />
    </input>
    <input name="UADOWNCommand">
        <btn name="kDown" />
    </input>
    <input name="UAToggleAdminTools">
        <btn name="kEnd" />
    </input>
    <input name="UAToggleMeshEsp">
        <btn name="kY" />
    </input>
    <input name="UAOpenAdminTools">
        <btn name="kHome" />
    </input>
    <input name="UATeleportToCrosshair">
        <btn name="kH" />
    </input>
    <input name="UADeleteObjCrosshair">
        <btn name="kDelete" />
    </input>
    <input name="UAToggleGodMode">
        <btn name="kInsert" />
    </input>
    <input name="UACamForward">
        <btn name="kW" />
    </input>
    <input name="UACamBackward">
        <btn name="kS" />
    </input>
    <input name="UACamRight">
        <btn name="kD" />
    </input>
    <input name="UACamLeft">
        <btn name="kA" />
    </input>
    <input name="UACamUp">
        <btn name="kQ" />
    </input>
    <input name="UACamDown">
        <btn name="kZ" />
    </input>
    <input name="UACamTurbo">
        <btn name="kLShift" />
    </input>
    <input name="UACamFOV">
        <btn name="kLControl" />
    </input>
    <input name="UARotateLeft">
        <btn name="mLeft" />
    </input>
    <input name="UARotateRight">
        <btn name="mRight" />
    </input>
    <input name="UACamShiftLeft">
        <btn name="mLeft" />
    </input>
    <input name="UACamShiftRight">
        <btn name="mRight" />
    </input>
    <input name="UACamShiftUp">
        <btn name="mUp" />
    </input>
    <input name="UACamShiftDown">
        <btn name="mDown" />
    </input>
    <input name="UACamSpeedAdd">
        <btn name="mWheelUp" />
    </input>
    <input name="UACamSpeedDeduct">
        <btn name="mWheelDown" />
    </input>
    <input name="UACamRelease">
        <btn name="kLControl" />
    </input>
    <input name="UAToggleInvis">
        <btn name="kI" />
    </input>
    <input name="UALBMADMCopyTarget">
        <btn name="kLControl">
            <btn name="kC" />
        </btn>
    </input>
    <input name="UALBMADMUndo">
        <btn name="kLControl">
            <btn name="kZ" />
        </btn>
    </input>
    <input name="UALBMADMRedo">
        <btn name="kLControl">
            <btn name="kY" />
        </btn>
    </input>
    <input name="UALBMADMHealSelf">
        <btn name="kLControl">
            <btn name="kH" />
        </btn>
    </input>
    <input name="UALBMADMOpenConsole">
        <btn name="kRControl">
            <btn name="kMinus" />
        </btn>
    </input>
    <input name="UALBMADMRepairTarget">
        <btn name="kLControl">
            <btn name="kR" />
        </btn>
    </input>
    <input name="UALBMADMPreset1">
        <btn name="kLControl">
            <btn name="k1" />
        </btn>
    </input>
    <input name="UALBMADMPreset2">
        <btn name="kLControl">
            <btn name="k2" />
        </btn>
    </input>
    <input name="UALBMADMPreset3">
        <btn name="kLControl">
            <btn name="k3" />
        </btn>
    </input>
    <input name="UALBMADMPreset4">
        <btn name="kLControl">
            <btn name="k4" />
        </btn>
    </input>
    <input name="UALBMADMPreset5">
        <btn name="kLControl">
            <btn name="k5" />
        </btn>
    </input>
    <input name="UALBMADMPreset6">
        <btn name="kLControl">
            <btn name="k6" />
        </btn>
    </input>
    <input name="UALBMADMPreset7">
        <btn name="kLControl">
            <btn name="k7" />
        </btn>
    </input>
    <input name="UALBMADMPreset8">
        <btn name="kLControl">
            <btn name="k8" />
        </btn>
    </input>
    <input name="UALBMADMPreset9">
        <btn name="kLControl">
            <btn name="k9" />
        </btn>
    </input>
    <input name="UALBMADMOpenMenu">
        <btn name="kLControl">
            <btn name="kA" />
        </btn>
    </input>
    <input name="UALBMADMTeleportToCursor">
        <btn name="kH" />
    </input>
    <input name="UALBMADMCopyPos">
        <btn name="kLControl">
            <btn name="kP" />
        </btn>
        <btn name="kRControl">
            <btn name="kP" />
        </btn>
    </input>
    <input name="UALBMADMDeleteCursor">
        <btn name="kLControl">
            <btn name="kD" />
        </btn>
    </input>
    <input name="UALBMADMDeleteCursorForce">
        <btn name="kLMenu">
            <btn name="kD" />
        </btn>
    </input>
    <input name="UALBMADMSpectatorZoomIn">
        <btn name="mWheelUp" />
    </input>
    <input name="UALBMADMSpectatorZoomOut">
        <btn name="mWheelDown" />
    </input>
    <input name="UALBMADMDuplicate">
        <btn name="kLControl">
            <btn name="kD" />
        </btn>
    </input>
    <input name="UALBMADMItemCopy">
        <btn name="kLControl">
            <btn name="kC" />
        </btn>
    </input>
    <input name="UALBMADMItemPaste">
        <btn name="kLControl">
            <btn name="kV" />
        </btn>
    </input>
    <input name="UALBMADMSpawnerGround">
        <btn name="kLControl">
            <btn name="kG" />
        </btn>
    </input>
    <input name="UALBMADMSpawnerInventory">
        <btn name="kLControl">
            <btn name="kS" />
        </btn>
    </input>
    <input name="UALBMADMSpawnerCursor">
        <btn name="kLControl">
            <btn name="kC" />
        </btn>
    </input>
    <input name="UALBMADMSpawnerTarget">
        <btn name="kLControl">
            <btn name="kT" />
        </btn>
    </input>
    <input name="UALBMADMToggleFreecam">
        <btn name="kLControl">
            <btn name="kF" />
        </btn>
    </input>
    <input name="UALBMADMToggleGodmode">
        <btn name="kLControl">
            <btn name="kG" />
        </btn>
    </input>
    <input name="UALBMADMToggleInvisible">
        <btn name="kRControl">
            <btn name="kI" />
        </btn>
    </input>
    <input name="UALBMADMToggleESP">
        <btn name="kLControl">
            <btn name="kE" />
        </btn>
    </input>
    <input name="UAExpansionConfirm">
        <btn name="kReturn" />
        <btn name="kNumpadEnter" />
    </input>
    <controller name="PCKeyboard">
        <limit name="doubleclick" value="0.500000" />
        <limit name="hold" value="0.330000" />
        <limit name="deadzone" value="0.000000" />
        <sensitivity name="vert" value="1.000000" />
        <sensitivity name="horz" value="1.000000" />
        <sensitivity name="curv" value="1.000000" />
        <sensitivity name="lvert" value="1.000000" />
        <sensitivity name="lhorz" value="1.000000" />
        <sensitivity name="lcurv" value="1.000000" />
        <sensitivity name="rvert" value="1.000000" />
        <sensitivity name="rhorz" value="1.000000" />
        <sensitivity name="rcurv" value="1.000000" />
        <sensitivity name="ldeadzone" value="1.000000" />
        <sensitivity name="rdeadzone" value="1.000000" />
    </controller>
    <controller name="PCMouse">
        <limit name="doubleclick" value="0.500000" />
        <limit name="hold" value="0.330000" />
        <limit name="deadzone" value="0.000000" />
        <sensitivity name="vert" value="0.550000" />
        <sensitivity name="horz" value="0.550000" />
        <sensitivity name="curv" value="1.000000" />
        <sensitivity name="lvert" value="1.000000" />
        <sensitivity name="lhorz" value="1.000000" />
        <sensitivity name="lcurv" value="1.000000" />
        <sensitivity name="rvert" value="1.000000" />
        <sensitivity name="rhorz" value="1.000000" />
        <sensitivity name="rcurv" value="1.000000" />
        <sensitivity name="ldeadzone" value="1.000000" />
        <sensitivity name="rdeadzone" value="1.000000" />
    </controller>
    <controller name="X1Controller">
        <limit name="doubleclick" value="0.500000" />
        <limit name="hold" value="0.330000" />
        <limit name="deadzone" value="0.030000" />
        <sensitivity name="vert" value="1.000000" />
        <sensitivity name="horz" value="1.000000" />
        <sensitivity name="curv" value="1.000000" />
        <sensitivity name="lvert" value="1.250000" />
        <sensitivity name="lhorz" value="1.250000" />
        <sensitivity name="lcurv" value="1.000000" />
        <sensitivity name="rvert" value="1.250000" />
        <sensitivity name="rhorz" value="1.250000" />
        <sensitivity name="rcurv" value="0.500000" />
        <sensitivity name="ldeadzone" value="0.030000" />
        <sensitivity name="rdeadzone" value="0.030000" />
    </controller>
    <controller name="PS4Controller">
        <limit name="doubleclick" value="0.500000" />
        <limit name="hold" value="0.330000" />
        <limit name="deadzone" value="0.030000" />
        <sensitivity name="vert" value="1.000000" />
        <sensitivity name="horz" value="1.000000" />
        <sensitivity name="curv" value="1.000000" />
        <sensitivity name="lvert" value="1.250000" />
        <sensitivity name="lhorz" value="1.250000" />
        <sensitivity name="lcurv" value="1.000000" />
        <sensitivity name="rvert" value="1.250000" />
        <sensitivity name="rhorz" value="1.250000" />
        <sensitivity name="rcurv" value="0.500000" />
        <sensitivity name="ldeadzone" value="0.030000" />
        <sensitivity name="rdeadzone" value="0.030000" />
    </controller>
    <controller name="IRTracker">
        <limit name="doubleclick" value="0.500000" />
        <limit name="hold" value="0.330000" />
        <limit name="deadzone" value="0.000000" />
        <sensitivity name="vert" value="1.000000" />
        <sensitivity name="horz" value="1.000000" />
        <sensitivity name="curv" value="1.000000" />
        <sensitivity name="lvert" value="1.000000" />
        <sensitivity name="lhorz" value="1.000000" />
        <sensitivity name="lcurv" value="1.000000" />
        <sensitivity name="rvert" value="1.000000" />
        <sensitivity name="rhorz" value="1.000000" />
        <sensitivity name="rcurv" value="1.000000" />
        <sensitivity name="ldeadzone" value="1.000000" />
        <sensitivity name="rdeadzone" value="1.000000" />
    </controller>
    <modificator name="aiming">
        <sensitivity name="vert" value="0.550000" />
        <sensitivity name="horz" value="0.550000" />
        <sensitivity name="rvert" value="1.250000" />
        <sensitivity name="rhorz" value="1.250000" />
        <sensitivity name="rcurv" value="0.500000" />
    </modificator>
    <modificator name="vehicle">
        <sensitivity name="lhorz" value="1.000000" />
    </modificator>
</preset>
  '';
}
