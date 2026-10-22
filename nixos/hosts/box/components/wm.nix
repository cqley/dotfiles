{ config, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
  };

  xdg.configFile."hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/hosts/box/components/hyprland.lua";
}
