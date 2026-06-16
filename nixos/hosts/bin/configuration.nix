{ config, pkgs, ... }:

{
  imports = [ 
    ./hardware-configuration.nix 
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services.getty.autologinUser = "cat";
  services.fstrim.enable = true;
  
  networking.hostName = "bin";
  networking.networkmanager.enable = true;

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
  programs.dconf.enable = true;

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

environment.systemPackages = with pkgs; [
    git
    kitty
    neovim
    btop
  ];

documentation.enable = false;
documentation.man.enable = false;

  system.stateVersion = "26.05";
}
