{ config, pkgs, ... }:

{
  imports = [
    ../../modules/system/files.nix
    ../../modules/system/btop.nix
    ../../modules/system/editor.nix
  ];

  home.username = "cat";
  home.homeDirectory = "/home/cat";
  home.stateVersion = "26.05";

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."btop/btop.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/#bin";
      update = "sudo nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#bin";
      system = "sudo nvim /etc/nixos"
    };
    functions = {
      fish_greeting = { body = ""; };
      fish_prompt = {
        body = ''
          echo -n (prompt_pwd)
          echo -n ' # '
        '';
      };
    };
  };

  programs.home-manager.enable = true;
}
