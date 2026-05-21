{ pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.conf".force = true;

  wayland.windowManager.hyprland = {
    enable = true;
    
    settings = {
      source = [ "~/.cache/wal/colors-hyprland.conf" ];

      monitor = [
        "HDMI-A-1, 1920x1080@200, 0x0, 1"
        "DP-1, 1920x1080@144, -1080x-330, 1, transform, 3"
      ];

      "$terminal" = "kitty";
      "$filemanager" = "nautilus";
      "$menu" = "rofi -show drun";
      "$browser" = "helium";
      "$mod" = "super";

      "exec-once" = [
        "systemctl --user start hyprpolkitagent"
        "awww-daemon & sleep 0.5 && awww clear --outputs DP-1"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "waybar"
        "hyprctl setcursor breeze_cursors 16"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 0;
        resize_on_border = 0;
        "col.active_border" = "$color2";
        allow_tearing = 0;
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
        rounding_power = 0;
        active_opacity = 1;
        inactive_opacity = 1;
        shadow = {
          enabled = 1;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = 1;
          size = 3;
          passes = 3;
          vibrancy = 0;
        };
      };

      animations = {
        enabled = "yes";
        bezier = [
          "easeOutQuint, 0.20, 1, 0.30, 1"
          "easeInOutCubic, 0.65, 0.05, 0.35, 1"
          "linear, 0, 0, 1, 1"
          "almostLinear, 0.5, 0.5, 0.75, 1"
          "quick, 0.15, 0, 0.1, 1"
          "hard, 0, 1, 0, 1"
        ];
        animation = [
          "global, 1, 5, default"
          "border, 1, 2.5, easeOutQuint"
          "windows, 1, 2.5, easeOutQuint"
          "windowsIn, 1, 2, easeOutQuint, popin 90%"
          "windowsOut, 1, 1, linear, popin 90%"
          "fadeIn, 1, 1, almostLinear"
          "fadeOut, 1, 1, almostLinear"
          "fade, 1, 1.5, quick"
          "layers, 1, 2, easeOutQuint"
          "layersIn, 1, 2, easeOutQuint, fade"
          "layersOut, 1, 1, linear, fade"
          "workspaces, 1, 1, almostLinear, fade"
          "specialWorkspace, 1, 1, almostLinear, fade"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        force_no_accel = 0;
        touchpad = {
          natural_scroll = 0;
        };
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = 1;
        disable_splash_rendering = 1;
        initial_workspace_tracking = 1;
      };

      dwindle = {
        preserve_split = 1;
      };

      windowrule = [
        "name:mv"
        "match:initial_class:^(imv|mpv)$"
        "float:on"
        "center:on"
        "size:600 600"
      ];

      workspace = [
        "w[t1], gapsout:0, gapsin:0, border:0, rounding:false"
        "f[1], gapsout:0, gapsin:0, border:0, rounding:false"
      ];

      bind = [
        "$mod, Q, exec, $terminal"
        "$mod, E, exec, $filemanager"
        "$mod, B, exec, $browser"
        "$mod, R, exec, $menu"
        "$mod, C, killactive"
        "$mod, V, togglefloating"
        "$mod, F, fullscreen, 0"
        "$mod, Tab, workspace, m+1"
        "$mod, T, exec, ~/.config/scripts/master.sh"
        "$mod, L, exec, ~/.config/scripts/power.sh"
        "$mod, W, exec, pkill -SIGUSR1 waybar"
        "$mod, P, exec, bash -c '[[ -f /tmp/hyprpickerlock ]] && exit; touch /tmp/hyprpickerlock; hyprpicker --no-zoom --autocopy; rm -f /tmp/hyprpickerlock'"
        "alt, S, exec, bash -c '[[ -f /tmp/slurplock ]] && exit; touch /tmp/slurplock; mkdir -p /home/silly/Pictures/screenshots; f=\"/home/silly/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\"; grim -g \"$(slurp)\" \"$f\" && wl-copy < \"$f\"; rm -f /tmp/slurplock'"
        
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "shift, left, movewindow, l"
        "shift, right, movewindow, r"
        "shift, up, movewindow, u"
        "shift, down, movewindow, d"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod shift, 1, movetoworkspace, 1"
        "$mod shift, 2, movetoworkspace, 2"
        "$mod shift, 3, movetoworkspace, 3"
        "$mod shift, 4, movetoworkspace, 4"
        "$mod shift, 5, movetoworkspace, 5"
        "$mod shift, 6, movetoworkspace, 6"
        "$mod shift, 7, movetoworkspace, 7"
        "$mod shift, 8, movetoworkspace, 8"
        "$mod shift, 9, movetoworkspace, 9"
        "$mod shift, 0, movetoworkspace, 10"

        "$mod, S, togglespecialworkspace, magic"
        "$mod shift, S, movetoworkspace, special:magic"

        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
