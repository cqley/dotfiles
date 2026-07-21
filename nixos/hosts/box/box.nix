{ config, pkgs, ... }:

{
  imports = [
    ../../mdls/wm.nix
    ../../mdls/qksh.nix
    ../../mdls/vi.nix
    ../../mdls/yazi.nix
    ../../mdls/btop.nix
    ../../mdls/colors.nix
    ../../mdls/notes.nix
    ../../mdls/gms/dayz.nix
    ../../mdls/gms/mc.nix
  ];

  home.username = "cat";
  home.homeDirectory = "/home/cat";
  home.stateVersion = "26.05";

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."kitty/kitty.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/#box";
      update = "nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#box";
    };
    functions = {
      fish_greeting = { body = ""; };
      fish_prompt = {
        body = ''
          echo -n (prompt_pwd)
          echo -n " % "
        '';
      };
    };
    interactiveShellInit = ''
      if status is-interactive
          cat ~/.colors/sequences
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
      include ~/.colors/kitty.conf

      shell fish
      shell_integration enabled

      font_family cherry
      font_size 10
      
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

  home.pointerCursor = {
    enable = true;
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
    QT_QPA_PLATFORMTHEME = "kde";
  };

  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
    font = { name = "MonaspiceNe Nerd Font Mono"; size = 11; };
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  "kdeglobals".source = pkgs.runCommand "breeze-dark-white" {} ''
    sed -E \
      -e 's/61,174,233/255,255,255/g' \
      -e 's/24,115,204/255,255,255/g' \
      -e 's/AccentColor=[0-9]+,[0-9]+,[0-9]+/AccentColor=255,255,255/' \
      "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors" > $out
  '';
};

  programs.home-manager.enable = true;
}
