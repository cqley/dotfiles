{ pkgs, ... }:

let
  colors-script = pkgs.writeShellScriptBin "colors" ''
    [ -z "$1" ] && echo "usage: colors <image>" >&2 && exit 1
    [ ! -f "$1" ] && echo "colors: file not found: $1" >&2 && exit 1

    colors="$HOME/.colors"
    mkdir -p "$colors"

    if hyprctl monitors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "HDMI-A-1"; then
        awww_out=$(${pkgs.awww}/bin/awww img -o HDMI-A-1 "$1" --transition-type grow --transition-duration 1.5 --transition-fps 120 2>&1)
        [ $? -ne 0 ] && echo "colors: awww: $awww_out" >&2
        ${pkgs.awww}/bin/awww clear --outputs DP-1 2>/dev/null
    else
        awww_out=$(${pkgs.awww}/bin/awww img "$1" --transition-type grow --transition-duration 1.5 --transition-fps 120 2>&1)
        [ $? -ne 0 ] && echo "colors: awww: $awww_out" >&2
    fi

    raw=$(${pkgs.imagemagick}/bin/magick "$1" -thumbnail 50x50^ -colors 8 -unique-colors txt:- 2>&1)

    base=$(printf '%s\n' "$raw" \
        | ${pkgs.gnugrep}/bin/grep -oE '#[0-9A-Fa-f]{6}' \
        | ${pkgs.gawk}/bin/awk '{
            r = strtonum("0x" substr($0,2,2))
            g = strtonum("0x" substr($0,4,2))
            b = strtonum("0x" substr($0,6,2))
            printf "%d %s\n", int(0.299*r + 0.587*g + 0.114*b), $0
        }' \
        | ${pkgs.coreutils}/bin/sort -n \
        | ${pkgs.gawk}/bin/awk '{print $2}' \
        | ${pkgs.coreutils}/bin/head -8)

    [ -z "$base" ] && echo "colors: magick failed" >&2 && echo "$raw" >&2 && exit 1

    n=$(printf '%s\n' "$base" | ${pkgs.coreutils}/bin/wc -l)
    last=$(printf '%s\n' "$base" | ${pkgs.coreutils}/bin/tail -1)
    while [ "$n" -lt 8 ]; do
        base=$(printf '%s\n%s' "$base" "$last")
        n=$((n+1))
    done

    bright=$(printf '%s\n' "$base" | ${pkgs.gawk}/bin/awk '{
        r = strtonum("0x" substr($0,2,2))
        g = strtonum("0x" substr($0,4,2))
        b = strtonum("0x" substr($0,6,2))
        r = int(r*1.4); if (r>255) r=255
        g = int(g*1.4); if (g>255) g=255
        b = int(b*1.4); if (b>255) b=255
        printf "#%02X%02X%02X\n", r, g, b
    }')

    cols=$(printf '%s\n%s' "$base" "$bright")

    c0=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '1p')
    c1=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '2p')
    c2=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '3p')
    c3=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '4p')
    c4=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '5p')
    c5=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '6p')
    c6=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '7p')
    c7=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '8p')
    c8=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '9p')
    c9=$(printf '%s\n'  "$cols" | ${pkgs.gnused}/bin/sed -n '10p')
    c10=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '11p')
    c11=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '12p')
    c12=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '13p')
    c13=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '14p')
    c14=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '15p')
    c15=$(printf '%s\n' "$cols" | ${pkgs.gnused}/bin/sed -n '16p')

    bg="$c0"
    fg=$(printf '%s\n' "$cols" | ${pkgs.gawk}/bin/awk -v bg="$c0" '
    function lum(hex,    r,g,b,rs,gs,bs) {
        r = strtonum("0x" substr(hex,2,2)) / 255
        g = strtonum("0x" substr(hex,4,2)) / 255
        b = strtonum("0x" substr(hex,6,2)) / 255
        rs = (r<=0.04045) ? r/12.92 : ((r+0.055)/1.055)^2.4
        gs = (g<=0.04045) ? g/12.92 : ((g+0.055)/1.055)^2.4
        bs = (b<=0.04045) ? b/12.92 : ((b+0.055)/1.055)^2.4
        return 0.2126*rs + 0.7152*gs + 0.0722*bs
    }
    function contrast(a,b,    l1,l2,t) {
        l1 = lum(a); l2 = lum(b)
        if (l1 < l2) { t=l1; l1=l2; l2=t }
        return (l1+0.05) / (l2+0.05)
    }
    BEGIN { best=""; bestc=0 }
    {
        c = contrast($0, bg)
        if (c > bestc) { bestc=c; best=$0 }
    }
    END { print best }
    ')
    cursor="$fg"

    printf '%s' "$1" > "$colors/colors"

    printf '%s\n' "$cols" | ${pkgs.gawk}/bin/awk '{printf "color%d=%s\n", NR-1, $0}' > "$colors/colors.sh"
    printf 'background="%s"\nforeground="%s"\ncursor="%s"\n' "$bg" "$fg" "$cursor" >> "$colors/colors.sh"

    cat > "$colors/colors.json" << ENDJSON
    {
        "wallpaper": "$1",
        "alpha": "100",
        "special": {
            "background": "$bg",
            "foreground": "$fg",
            "cursor": "$cursor"
        },
        "colors": {
            "color0": "$c0",
            "color1": "$c1",
            "color2": "$c2",
            "color3": "$c3",
            "color4": "$c4",
            "color5": "$c5",
            "color6": "$c6",
            "color7": "$c7",
            "color8": "$c8",
            "color9": "$c9",
            "color10": "$c10",
            "color11": "$c11",
            "color12": "$c12",
            "color13": "$c13",
            "color14": "$c14",
            "color15": "$c15"
        }
    }
    ENDJSON

    printf '%s\n' "$cols" > "$colors/colors.txt"

    cat > "$colors/kitty.conf" << ENDKITTY
    foreground         $fg
    background         $bg
    background_opacity 1.0
    cursor             $cursor

    active_tab_foreground     $bg
    active_tab_background     $fg
    inactive_tab_foreground   $fg
    inactive_tab_background   $bg

    active_border_color   $fg
    inactive_border_color $bg
    bell_border_color     $c1

    color0       $c0
    color8       $c8
    color1       $c1
    color9       $c9
    color2       $c2
    color10      $c10
    color3       $c3
    color11      $c11
    color4       $c4
    color12      $c12
    color5       $c5
    color13      $c13
    color6       $c6
    color14      $c14
    color7       $c7
    color15      $c15
    ENDKITTY

    cat > "$colors/colors.fish" << ENDFISH
    set fish_color_autosuggestion \$(echo "$c8" | sed 's/#//')
    set fish_color_cancel \$(echo "$c1" | sed 's/#//') '--reverse'
    set fish_color_command \$(echo "$c10" | sed 's/#//')
    set fish_color_comment \$(echo "$c8" | sed 's/#//')
    set fish_color_cwd \$(echo "$c2" | sed 's/#//')
    set fish_color_cwd_root \$(echo "$c1" | sed 's/#//')
    set fish_color_end \$(echo "$c3" | sed 's/#//')
    set fish_color_error \$(echo "$c1" | sed 's/#//')
    set fish_color_escape \$(echo "$c5" | sed 's/#//')
    set fish_color_history_current --bold
    set fish_color_host \$(echo "$c12" | sed 's/#//')
    set fish_color_host_remote \$(echo "$c12" | sed 's/#//')
    set fish_color_keyword \$(echo "$c5" | sed 's/#//')
    set fish_color_match --background=\$(echo "$c4" | sed 's/#//')
    set fish_color_normal \$(echo "$fg" | sed 's/#//')
    set fish_color_operator \$(echo "$c6" | sed 's/#//')
    set fish_color_option \$(echo "$c3" | sed 's/#//')
    set fish_color_param \$(echo "$c12" | sed 's/#//')
    set fish_color_quote \$(echo "$c11" | sed 's/#//')
    set fish_color_redirection \$(echo "$c5" | sed 's/#//')
    set fish_color_search_match --background=\$(echo "$c8" | sed 's/#//')
    set fish_color_selection --background=\$(echo "$c8" | sed 's/#//')
    set fish_color_status \$(echo "$c1" | sed 's/#//')
    set fish_color_user \$(echo "$c10" | sed 's/#//')
    set fish_color_valid_path --underline
    set fish_pager_color_background \$(echo "$bg" | sed 's/#//')
    set fish_pager_color_completion \$(echo "$fg" | sed 's/#//')
    set fish_pager_color_description \--background=\$(echo "$c8" | sed 's/#//')
    set fish_pager_color_prefix \$(echo "$c10" | sed 's/#//')
    set fish_pager_color_progress \$(echo "$c8" | sed 's/#//')
    set fish_pager_color_secondary_background \$(echo "$bg" | sed 's/#//')
    set fish_pager_color_secondary_completion \$(echo "$fg" | sed 's/#//')
    set fish_pager_color_secondary_description \$(echo "$c8" | sed 's/#//')
    set fish_pager_color_secondary_prefix \$(echo "$c10" | sed 's/#//')
    set fish_pager_color_selected_background --background=\$(echo "$c8" | sed 's/#//')
    set fish_pager_color_selected_completion \$(echo "$fg" | sed 's/#//')
    set fish_pager_color_selected_description \$(echo "$c8" | sed 's/#//')
    set fish_pager_color_selected_prefix \$(echo "$c10" | sed 's/#//')
    ENDFISH

    {
        printf '%s\n' "$cols" | ${pkgs.gawk}/bin/awk '{printf "\033]4;%d;%s\007", NR-1, $0}'
        printf '\033]10;%s\007' "$fg"
        printf '\033]11;%s\007' "$bg"
        printf '\033]12;%s\007' "$cursor"
    } > "$colors/sequences"

    for pty in /proc/*/fd/0; do
        [ -c "$pty" ] && [ -w "$pty" ] && ${pkgs.coreutils}/bin/cat "$colors/sequences" > "$pty" 2>/dev/null
    done

    printf '%s\n' "$base" | ${pkgs.gawk}/bin/awk '{
        r = strtonum("0x" substr($0,2,2))
        g = strtonum("0x" substr($0,4,2))
        b = strtonum("0x" substr($0,6,2))
        printf "\033[48;2;%d;%d;%dm   \033[0m %s\n", r, g, b, $0
    }'
  '';
in
{
  home.packages = [ colors-script ];
}
