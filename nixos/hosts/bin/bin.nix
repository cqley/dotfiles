{ config, pkgs, ... }:

{
  imports = [
    ../../mdls/vi.nix
    ../../mdls/btop.nix
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
      update = "nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#bin";
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
  };

  programs.home-manager.enable = true;
}
