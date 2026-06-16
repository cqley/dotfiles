{ config, pkgs, ... }:

{
  imports = [
    ../../mdls/hypr.nix
    ../../mdls/qksh.nix
    ../../mdls/vim.nix
  ];

  home.username = "cat";
  home.homeDirectory = "/home/cat";
  home.stateVersion = "26.05";

  home.packages = [ cls ];

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."kitty/kitty.conf".force = true;
  xdg.configFile."btop/btop.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/#$hostname";
      update = "nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#$hostname";
    };
    functions = {
      fish_greeting = { body = ""; };
      fish_prompt = {
        body = ''
          echo -n (prompt_pwd)
          echo -n " > "
        '';
      };
    };
    interactiveShellInit = ''
      if status is-interactive
          cat ~/.cls/sequences
      end
    '';
    loginShellInit = ''
      if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
        exec start-hyprland
      end
    '';
  };

  programs.kitty = {
    enable = true;
    extraConfig = ''
      include ~/.cls/kitty.conf

      shell fish
      shell_integration enabled

      font_family JetBrainsMono Nerd Font
      font_size 11
      
      cursor_trail 3
      cursor_trail_decay 0.1 0.4
      cursor_shape beam
      cursor_blink_interval 1
      shell_integration no-cursor

      confirm_os_window_close 0
      allow_remote_control yes

      background_opacity 1
      background_blur 1
      dynamic_background_opacity 1
      scrollbar_handle_opacity 0
      scrollbar_track_opacity 0
      scrollbar_track_hover_opacity 0
    '';
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "TTY";
      theme_background = true;
      truecolor = true;
      force_tty = false;
      presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
      vim_keys = false;
      rounded_corners = false;
      terminal_sync = true;
      update_ms = 2000;
      background_update = true;
      clock_format = "%X";
      base_10_sizes = false;
      base_10_bitrate = "Auto";
      log_level = "WARNING";
      save_config_on_exit = true;
      shown_boxes = "cpu mem net proc";
      graph_symbol = "braille";
      graph_symbol_cpu = "default";
      graph_symbol_gpu = "default";
      graph_symbol_mem = "default";
      graph_symbol_net = "default";
      graph_symbol_proc = "default";
      cpu_bottom = false;
      cpu_graph_upper = "Auto";
      cpu_graph_lower = "Auto";
      cpu_invert_lower = true;
      cpu_single_graph = false;
      check_temp = true;
      cpu_sensor = "Auto";
      show_coretemp = true;
      cpu_core_map = "";
      temp_scale = "celsius";
      show_cpu_freq = true;
      freq_mode = "first";
      show_cpu_watts = true;
      show_uptime = true;
      custom_cpu_name = "";
      proc_left = false;
      proc_sorting = "cpu lazy";
      proc_reversed = false;
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = false;
      proc_mem_bytes = true;
      proc_cpu_graphs = true;
      proc_info_smaps = false;
      proc_filter_kernel = false;
      proc_aggregate = false;
      keep_dead_proc_usage = false;
      mem_graphs = true;
      mem_below_net = false;
      show_swap = true;
      swap_disk = true;
      zfs_arc_cached = true;
      show_disks = true;
      disks_filter = "";
      only_physical = true;
      use_fstab = true;
      disk_free_priv = false;
      show_io_stat = true;
      io_mode = false;
      io_graph_combined = false;
      io_graph_speeds = "";
      zfs_hide_datasets = false;
      net_iface = "";
      net_auto = true;
      net_sync = true;
      net_download = 100;
      net_upload = 100;
      show_gpu_info = "Auto";
      shown_gpus = "nvidia";
      gpu_mirror_graph = true;
      nvml_measure_pcie_speeds = true;
      rsmi_measure_pcie_speeds = true;
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.kdePackages.breeze;
    name = "breeze_cursors";
    size = 16;
  };

  home.sessionVariables = {
    XCURSOR_THEME = "breeze_cursors";
    XCURSOR_SIZE = "16";
    QT_CURSOR_SIZE = "16";
  };

  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
    font = { name = "MonaspiceNe Nerd Font Mono"; size = 11; };
  };

let
  cls = pkgs.writeShellScriptBin "cls" ''
    [ -z "$1" ] && echo "usage: cls <image>" >&2 && exit 1
    [ ! -f "$1" ] && echo "cls: file not found: $1" >&2 && exit 1

    cls="$HOME/.cls"
    mkdir -p "$cls"

    awww_out=$(awww img -o HDMI-A-1 "$1" --transition-type grow --transition-duration 1.5 --transition-fps 120 2>&1)
    [ $? -ne 0 ] && echo "cls: awww: $awww_out" >&2
    awww clear --outputs DP-1 2>/dev/null

    raw=$(magick "$1" -thumbnail 50x50^ -colors 8 -unique-colors txt:- 2>&1)

    base=$(printf '%s\n' "$raw" \
        | grep -oE '#[0-9A-Fa-f]{6}' \
        | awk '{
            r = strtonum("0x" substr($0,2,2))
            g = strtonum("0x" substr($0,4,2))
            b = strtonum("0x" substr($0,6,2))
            printf "%d %s\n", int(0.299*r + 0.587*g + 0.114*b), $0
        }' \
        | sort -n \
        | awk '{print $2}' \
        | head -8)

    [ -z "$base" ] && echo "cls: magick failed" >&2 && echo "$raw" >&2 && exit 1

    n=$(printf '%s\n' "$base" | wc -l)
    last=$(printf '%s\n' "$base" | tail -1)
    while [ "$n" -lt 8 ]; do
        base=$(printf '%s\n%s' "$base" "$last")
        n=$((n+1))
    done

    bright=$(printf '%s\n' "$base" | awk '{
        r = strtonum("0x" substr($0,2,2))
        g = strtonum("0x" substr($0,4,2))
        b = strtonum("0x" substr($0,6,2))
        r = int(r*1.4); if (r>255) r=255
        g = int(g*1.4); if (g>255) g=255
        b = int(b*1.4); if (b>255) b=255
        printf "#%02X%02X%02X\n", r, g, b
    }')

    cols=$(printf '%s\n%s' "$base" "$bright")

    c0=$(printf '%s\n'  "$cols" | sed -n '1p')
    c1=$(printf '%s\n'  "$cols" | sed -n '2p')
    c2=$(printf '%s\n'  "$cols" | sed -n '3p')
    c3=$(printf '%s\n'  "$cols" | sed -n '4p')
    c4=$(printf '%s\n'  "$cols" | sed -n '5p')
    c5=$(printf '%s\n'  "$cols" | sed -n '6p')
    c6=$(printf '%s\n'  "$cols" | sed -n '7p')
    c7=$(printf '%s\n'  "$cols" | sed -n '8p')
    c8=$(printf '%s\n'  "$cols" | sed -n '9p')
    c9=$(printf '%s\n'  "$cols" | sed -n '10p')
    c10=$(printf '%s\n' "$cols" | sed -n '11p')
    c11=$(printf '%s\n' "$cols" | sed -n '12p')
    c12=$(printf '%s\n' "$cols" | sed -n '13p')
    c13=$(printf '%s\n' "$cols" | sed -n '14p')
    c14=$(printf '%s\n' "$cols" | sed -n '15p')
    c15=$(printf '%s\n' "$cols" | sed -n '16p')

    bg="$c0"
    fg=$(printf '%s\n' "$cols" | awk -v bg="$c0" '
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

    printf '%s' "$1" > "$cls/cls"

    printf '%s\n' "$cols" | awk '{printf "color%d=\"%s\"\n", NR-1, $0}' > "$cls/cls.sh"
    printf 'background="%s"\nforeground="%s"\ncursor="%s"\n' "$bg" "$fg" "$cursor" >> "$cls/cls.sh"

    cat > "$cls/cls.json" << ENDJSON
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

    printf '%s\n' "$cols" > "$cls/colors.txt"

    cat > "$cls/kitty.conf" << ENDKITTY
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

    cat > "$cls/colors.fish" << ENDFISH
    set fish_color_autosuggestion ''${c8#?}
    set fish_color_cancel ''${c1#?} '--reverse'
    set fish_color_command ''${c10#?}
    set fish_color_comment ''${c8#?}
    set fish_color_cwd ''${c2#?}
    set fish_color_cwd_root ''${c1#?}
    set fish_color_end ''${c3#?}
    set fish_color_error ''${c1#?}
    set fish_color_escape ''${c5#?}
    set fish_color_history_current --bold
    set fish_color_host ''${c12#?}
    set fish_color_host_remote ''${c12#?}
    set fish_color_keyword ''${c5#?}
    set fish_color_match --background=''${c4#?}
    set fish_color_normal ''${fg#?}
    set fish_color_operator ''${c6#?}
    set fish_color_option ''${c3#?}
    set fish_color_param ''${c12#?}
    set fish_color_quote ''${c11#?}
    set fish_color_redirection ''${c5#?}
    set fish_color_search_match --background=''${c8#?}
    set fish_color_selection --background=''${c8#?}
    set fish_color_status ''${c1#?}
    set fish_color_user ''${c10#?}
    set fish_color_valid_path --underline
    set fish_pager_color_background ''${bg#?}
    set fish_pager_color_completion ''${fg#?}
    set fish_pager_color_description ''${c8#?}
    set fish_pager_color_prefix ''${c10#?}
    set fish_pager_color_progress ''${c8#?}
    set fish_pager_color_secondary_background ''${bg#?}
    set fish_pager_color_secondary_completion ''${fg#?}
    set fish_pager_color_secondary_description ''${c8#?}
    set fish_pager_color_secondary_prefix ''${c10#?}
    set fish_pager_color_selected_background --background=''${c8#?}
    set fish_pager_color_selected_completion ''${fg#?}
    set fish_pager_color_selected_description ''${c8#?}
    set fish_pager_color_selected_prefix ''${c10#?}
    ENDFISH

    {
        printf '%s\n' "$cols" | awk '{printf "\033]4;%d;%s\007", NR-1, $0}'
        printf '\033]10;%s\007' "$fg"
        printf '\033]11;%s\007' "$bg"
        printf '\033]12;%s\007' "$cursor"
    } > "$cls/sequences"

    for pty in /proc/*/fd/0; do
        [ -c "$pty" ] && [ -w "$pty" ] && cat "$cls/sequences" > "$pty" 2>/dev/null
    done

    printf '%s\n' "$base" | awk '{
        r = strtonum("0x" substr($0,2,2))
        g = strtonum("0x" substr($0,4,2))
        b = strtonum("0x" substr($0,6,2))
        printf "\033[48;2;%d;%d;%dm   \033[0m %s\n", r, g, b, $0
    }'
  '';
in

  home.file = {
    ".documents/obsidian/.obsidian/app.json".text = builtins.toJSON {
      readableLineLength = true;
      foldHeading = true;
      showLineNumber = true;
      spellcheck = false;
      vimMode = false;
      newFileLocation = "current";
      promptDelete = false;
    };

    ".documents/obsidian/.obsidian/appearance.json".text = builtins.toJSON {
      accentColor = "#ffa8db";
      cssTheme = "";
      theme = "obsidian";
    };

    ".documents/obsidian/.obsidian/core-plugins.json".text = builtins.toJSON {
      "file-explorer" = true;
      "global-search" = true;
      "switcher" = false;
      "graph" = true;
      "backlink" = false;
      "canvas" = false;
      "outgoing-link" = true;
      "tag-pane" = true;
      "footnotes" = false;
      "properties" = false;
      "page-preview" = true;
      "daily-notes" = true;
      "templates" = false;
      "note-composer" = false;
      "command-palette" = false;
      "slash-command" = false;
      "editor-status" = true;
      "bookmarks" = false;
      "markdown-importer" = false;
      "zk-prefixer" = false;
      "random-note" = false;
      "outline" = true;
      "word-count" = true;
      "slides" = false;
      "audio-recorder" = false;
      "workspaces" = false;
      "file-recovery" = true;
      "publish" = false;
      "sync" = false;
      "bases" = false;
      "webviewer" = false;
    };

  systemd.user.services.obsidian = {
    Unit.Description = "obsidian git sync";
    Service = {
      ExecStart = "${pkgs.writeShellScript "obsidian" ''
        while true; do
          cd /home/cat/.documents/obsidian || exit 1
          if [ ! -d .git ]; then
            exit 1
          fi
          git add .
          if ! git diff-index --quiet HEAD; then
            git commit -m "sync $(date +'%Y-%m-%d %H:%M:%S')"
            git pull --rebase origin main
            git push origin main
          fi
          sleep 60
        done
      ''}";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.home-manager.enable = true;
}
