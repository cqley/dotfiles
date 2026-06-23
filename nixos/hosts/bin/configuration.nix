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

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
  
  networking.hostName = "bin";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 5657 ];

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
  };

  environment.systemPackages = with pkgs; [
    git
    neovim
    btop
  ];

  services.openssh = {
    enable = true;
    settings = {
	    PasswordAuthentication = true;
    };
  };

  services.pufferpanel = {
    enable = true;
    extraPackages = [ pkgs.jdk25 ];
    environment = {
      PUFFER_WEB_HOST = ":8080";
      PUFFER_DAEMON_SFTP_HOST = ":5657";
    };
  };

  documentation.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "26.05";
}
