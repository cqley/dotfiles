{ pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua".force = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    extraConfig = ''
      local hl = hl
      local dsp = hl.dsp
      local bind = hl.bind
      local config = hl.config
      local curve = hl.curve
      local animation = hl.animation
      local exec = dsp.exec_cmd
      local focus = dsp.focus
      local window = dsp.window
      local workspace = dsp.workspace

      hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@200", position = "0x0", scale = 1 })
      hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "-1080x-330", scale = 1, transform = 3 })

      local mod = "SUPER"
      local terminal = "kitty"
      local filemanager = "dolphin"
      local browser = "helium"

      hl.on("hyprland.start", function ()
          exec("systemctl --user start hyprpolkitagent")
          exec("bash -c 'awww-daemon & sleep 0.5 && awww clear --outputs DP-1'")
          exec("wl-paste --type text --watch cliphist store")
          exec("wl-paste --type image --watch cliphist store")
          exec("quickshell -c ~/.config/quickshell")
      end)

      config({
          general = {
              gaps_in = 2.5,
              gaps_out = 5,
              border_size = 1,
              resize_on_border = false,
              col = { active_border = "rgba(ffffffff)" },
              allow_tearing = false,
              layout = "dwindle",
          },
      })

      config({
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

      config({
          input = {
              kb_layout = "us",
              follow_mouse = 1,
              sensitivity = 0,
              force_no_accel = false,
              touchpad = { natural_scroll = false },
          },
      })

      config({
          misc = {
              force_default_wallpaper = 0,
              disable_hyprland_logo = true,
              disable_splash_rendering = true,
              initial_workspace_tracking = true,
          },
      })

      config({
          dwindle = {
              preserve_split = true,
          },
      })

      curve("easeOutQuint", { type = "bezier", points = { {0.20, 1}, {0.30, 1} } })
      curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.35, 1} } })
      curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
      curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
      curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
      curve("hard", { type = "bezier", points = { {0, 1}, {0, 1} } })
      animation({ leaf = "global", enabled = true, speed = 5, bezier = "default" })
      animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
      animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
      animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "popin 90%" })
      animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "linear", style = "popin 90%" })
      animation({ leaf = "fadeIn", enabled = true, speed = 1, bezier = "almostLinear" })
      animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "almostLinear" })
      animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "quick" })
      animation({ leaf = "layers", enabled = true, speed = 2, bezier = "easeOutQuint" })
      animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
      animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
      animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })
      animation({ leaf = "specialWorkspace", enabled = true, speed = 1, bezier = "almostLinear", style = "fade" })

      hl.window_rule({
          match = { initial_class = "^(imv|mpv)$" },
          float = true,
          center = true,
          size = "600 600",
      })

      bind(mod .. " + Q", exec(terminal))
      bind(mod .. " + R", exec("quickshell ipc call menu toggle"))
      bind(mod .. " + T", exec("quickshell ipc call master toggle"))
      bind(mod .. " + W", exec("quickshell ipc call bar toggle"))
      bind(mod .. " + X", exec("quickshell ipc call mic toggle"))
      bind(mod .. " + E", exec(filemanager))
      bind(mod .. " + B", exec(browser))
      bind(mod .. " + C", window.close())
      bind(mod .. " + V", window.float({ action = "toggle" }))
      bind(mod .. " + F", window.fullscreen({ mode = 0 }))
      bind(mod .. " + Tab", focus({ workspace = "m+1" }))
      bind("ALT + S", exec('hyprshot -o .pictures/screenshots/ -f "$(date +%y-%m-%d_%H-%M-%S).png" -s -m region'))

      bind(mod .. " + left",  focus({ direction = "left" }))
      bind(mod .. " + right", focus({ direction = "right" }))
      bind(mod .. " + up",    focus({ direction = "up" }))
      bind(mod .. " + down",  focus({ direction = "down" }))

      bind("SHIFT + left",  window.move({ direction = "left" }))
      bind("SHIFT + right", window.move({ direction = "right" }))
      bind("SHIFT + up",    window.move({ direction = "up" }))
      bind("SHIFT + down",  window.move({ direction = "down" }))

      for i = 1, 10 do
          local key = (i == 10) and "0" or tostring(i)
          bind(mod .. " + " .. key, focus({ workspace = i }))
          bind(mod .. " + SHIFT + " .. key, window.move({ workspace = i }))
      end

      bind(mod .. " + S", workspace.toggle_special("magic"))
      bind(mod .. " + SHIFT + " .. "S", window.move({ workspace = "special:magic" }))

      bind(mod .. " + mouse:272", window.drag(), { mouse = true })
      bind(mod .. " + mouse:273", window.resize(), { mouse = true })
    '';
  };
}
