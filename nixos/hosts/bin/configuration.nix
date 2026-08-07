{ config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
    ./components/wireguard.nix
    ./components/cgit.nix
    ./components/pufferpanel.nix
    ./components/music.nix
    ./components/immich.nix
    ../../modules/misc/shared.nix
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
    device = "/dev/sda";
  };
  
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
  
  networking.hostName = "bin";
  networking.networkmanager.enable = true;

  networking.useDHCP = false;
  networking.interfaces.ens18.ipv4.addresses = [{
    address = "5.231.118.153";
    prefixLength = 24;
  }];
  networking.defaultGateway = {
    address = "5.231.118.1";
    interface = "ens18";
  };
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

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
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJq3Lw3QReo6e9S1jbt1AywvaLKfgTY/GagPsfReP+t cat@box"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlgxVpCMZUQkhkpepEkJ4IoOz/EtnxSoh38qisHMGPn cat@bed"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    kitty
    wireguard-tools
  ];

  services.nscd.enable = false;
  system.nssModules = lib.mkForce [];
  
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  documentation.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "26.05";
}
