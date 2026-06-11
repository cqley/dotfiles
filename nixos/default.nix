{ pkgs, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  nixpkgs.config.allowUnfree = true;

  programs.fish.enable = true;

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  environment.systemPackages = with pkgs; [
    btop
    git
    neovim
  ];

  documentation.enable = false;
  documentation.man.enable = false;
}
