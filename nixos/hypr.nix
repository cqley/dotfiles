{ pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua".force = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    extraConfig = ''
      hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@200", position = "0x0", scale = 1 })
      hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "-1080x-330", scale = 1, transform = 3 })

      local mainMod = "SUPER"
      local terminal = "kitty"
      local filemanager = "nautilus"
      local menu = "rofi -show drun"
      local browser = "helium"

      hl.on("hyprland.start", function ()
          hl.exec_cmd("systemctl --user start hyprpolkitagent")
          hl.exec_cmd("bash -c 'awww-daemon & sleep 0.5 && awww clear --outputs DP-1'")
          hl.exec_cmd("wl-paste --type text --watch cliphist store")
          hl.exec_cmd("wl-paste --type image --watch cliphist store")
          hl.exec_cmd("quickshell -c ~/.config/quickshell")
      end)

      hl.config({
          general = {
              gaps_in = 5,
              gaps_out = 10,
              border_size = 2,
              resize_on_border = false,
              col = {
                  active_border = color2 or "rgba(33ccffee)",
              },
              allow_tearing = false,
              layout = "dwindle",
          },
      })

      hl.config({
          decoration = {
              rounding = 0,
              rounding_power = 0,
              active_opacity = 1.0,
              inactive_opacity = 1.0,
              shadow = {
                  enabled = true,
                  range = 4,
                  render_power = 3,
                  color = "rgba(1a1a1aee)",
              },
              blur = {
                  enabled = true,
                  size = 3,
                  passes = 3,
                  vibrancy = 0,
              },
          },
      })

      hl.curve("easeOutQuint", { type = "bezier", points = { {0.20, 1}, {0.30, 1} } })
      hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.35, 1} } })
      hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
      hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
      hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
      hl.curve("hard", { type = "bezier", points = { {0, 1}, {0, 1} } })
      hl.animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
      hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
      hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
      hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "popin 90%" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "linear", style = "popin 90%" })
      hl.animation({ leaf = "fadeIn", enabled = true, speed = 1, bezier = "almostLinear" })
      hl.animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "almostLinear" })
      hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "quick" })
      hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "easeOutQuint" })
      hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
      hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })
      hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })

      hl.config({
          input = {
              kb_layout = "us",
              follow_mouse = 1,
              sensitivity = 0,
              force_no_accel = false,
              touchpad = {
                  natural_scroll = false,
              },
          },
      })

      hl.config({
          misc = {
              force_default_wallpaper = 0,
              disable_hyprland_logo = true,
              disable_splash_rendering = true,
              initial_workspace_tracking = true,
          },
      })

      hl.config({
          dwindle = {
              preserve_split = true,
          },
      })

      hl.window_rule({
          match = {
              initial_class = "^(imv|mpv)$",
          },
          float = true,
          center = true,
          size = "600 600",
      })

      hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 10, gaps_in = 0 })
      --hl.workspace_rule({ workspace = "f",   gaps_out = 10, gaps_in = 0 })
      hl.window_rule({
           name  = "no-gaps-wtv1",
           match = { float = false, workspace = "w[tv1]" },
           border_size = 2,
           rounding    = 0,
       })
       hl.window_rule({
           name  = "no-gaps-f1",
           match = { float = false, workspace = "f" },
           border_size = 2,
           rounding    = 0,
       })

      hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager))
      hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
      hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + C", hl.dsp.window.close())
      hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
      hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
      hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("master"))
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
      hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("bash -c '[[ -f /tmp/hyprpickerlock ]] && exit; touch /tmp/hyprpickerlock; hyprpicker --no-zoom --autocopy; rm -f /tmp/hyprpickerlock'"))
      hl.bind("ALT + S", hl.dsp.exec_cmd("bash -c '[[ -f /tmp/slurplock ]] && exit; touch /tmp/slurplock; mkdir -p /home/silly/Pictures/screenshots; f=\"/home/silly/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\"; grim -g \"$(slurp)\" \"$f\" && wl-copy < \"$f\"; rm -f /tmp/slurplock'"))

      hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

      hl.bind("SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
      hl.bind("SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind("SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
      hl.bind("SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

      hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
      hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
      hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
      hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
      hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
      hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
      hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
      hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
      hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
      hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

      hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
      hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
      hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
      hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
      hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
      hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
      hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
      hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
      hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
      hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

      hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
    '';
  };
}
