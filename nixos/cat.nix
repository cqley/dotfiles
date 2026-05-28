{ config, pkgs, ... }:

{
  imports = [
    ./hypr.nix
    ./vim.nix
  ];

  home.username = "silly";
  home.homeDirectory = "/home/silly";
  home.stateVersion = "25.11";

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."kitty/kitty.conf".force = true;
  xdg.configFile."dunst/dunstrc".force = true;
  xdg.configFile."btop/btop.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/#cat";
      update = "nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#cat";
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
          cat ~/.cache/wal/sequences
      end
    '';
  };

  programs.kitty = {
    enable = true;
    extraConfig = ''
      include ~/.cache/wal/colors-kitty.conf

      shell fish
      shell_integration enabled

      cursor_trail 3
      cursor_trail_decay 0.1 0.4
      cursor_shape beam
      cursor_blink_interval 1
      shell_integration no-cursor

      confirm_os_window_close 0
      allow_remote_control yes

      background_opacity 0.7
      background_blur 1
      dynamic_background_opacity 1
      scrollbar_handle_opacity 0
      scrollbar_track_opacity 0
      scrollbar_track_hover_opacity 0
    '';
  };

  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "15x15";
        monitor = 1;
        follow = "none";
        width = 250;
        height = "0x75";
        frame_width = 2;
        frame_color = "#ffffff";
        corner_radius = 0;
        background = "#000000";
        foreground = "#ffffff";
        separator_color = "frame";
        separator_height = 2;
        padding = 15;
        horizontal_padding = 20;
        icon_position = "left";
        max_icon_size = 32;
        markup = "full";
        format = "<span foreground='#ffffff'><b>%s</b></span>\n%b";
        alignment = "left";
        word_wrap = "yes";
        sort = "no";
        stack_duplicates = "false";
        notification_limit = 1;
        indicate_hidden = "yes";
        override_dbus_timeout = 3;
      };
      urgency_critical = {
        background = "#ff0000";
        foreground = "#ffffff";
        frame_color = "#ffffff";
        override_dbus_timeout = 5;
      };
    };
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

home.packages = with pkgs; [
  (writeShellScriptBin "master" ''
    options="config\nsettings\nwallpaper\npower"
    choice=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p ">")

    case "$choice" in
        *config*)    exec "config" ;;
        *settings*)  exec "settings" ;;
        *wallpaper*) exec "wallpaper" ;;
        *power*)     exec "power" ;;
    esac
  '')

  (writeShellScriptBin "config" ''
    options="nix\ncat\nhypr\nvim\nrofi\nzed\ncsgo\ncs2"
    choice=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p ">")

    case "$choice" in
        *nix*)      ${pkgs.kitty}/bin/kitty -e sudo nvim "/etc/nixos/configuration.nix" ;;
        *cat*)      ${pkgs.kitty}/bin/kitty -e sudo nvim "/etc/nixos/cat.nix" ;;
        *hypr*)     ${pkgs.kitty}/bin/kitty -e sudo nvim "/etc/nixos/hypr.nix" ;;
        *vim*)      ${pkgs.kitty}/bin/kitty -e sudo nvim "/etc/nixos/vim.nix" ;;
        *rofi*)     ${pkgs.zed-editor}/bin/zeditor "$HOME/.config/rofi/" ;;
        *zed*)      ${pkgs.zed-editor}/bin/zeditor "$HOME/.config/zed/settings.json" ;;
        *csgo*)     ${pkgs.zed-editor}/bin/zeditor "$HOME/.local/share/Steam/steamapps/common/csgo legacy/csgo/cfg/autoexec.cfg" ;;
        *cs2*)      ${pkgs.zed-editor}/bin/zeditor "$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg" ;;
    esac
  '')

  (writeShellScriptBin "settings" ''
    options="fade\nvertical\nhorizontal"
    choice=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p ">")

    case "$choice" in
        fade)
            hyprctl eval 'hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })' > /dev/null
            hyprctl eval 'hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })' > /dev/null
            ${pkgs.libnotify}/bin/notify-send "animations" "fade" ;;
        vertical)
            hyprctl eval 'hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "hard", style = "slidevert" })' > /dev/null
            hyprctl eval 'hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "hard", style = "slidevert" })' > /dev/null
            ${pkgs.libnotify}/bin/notify-send "animations" "vertical" ;;
        horizontal)
            hyprctl eval 'hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "hard", style = "slide" })' > /dev/null
            hyprctl eval 'hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "hard", style = "slide" })' > /dev/null
            ${pkgs.libnotify}/bin/notify-send "animations" "horizontal" ;;
    esac
  '')

  (writeShellScriptBin "power" ''
    options="lock\nlogout\nreboot\nshutdown"
    choice=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p ">")

    case "$choice" in
        *lock*)     ${pkgs.hyprlock}/bin/hyprlock ;;
        *logout*)   hyprctl dispatch exit ;;
        *reboot*)   systemctl reboot ;;
        *shutdown*) systemctl poweroff ;;
    esac
  '')
];

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

  programs.home-manager.enable = true;
}
