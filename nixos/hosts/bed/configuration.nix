{ config, pkgs, pkgs-unstable, ... }:

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
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services.getty.autologinUser = "cat";
  services.fstrim.enable = true;
  
  networking.hostName = "bed";
  networking.networkmanager.enable = true;
  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.3/24" ];
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      {
        publicKey = "P2LPLBq/6qXE5Mmv8DJUviU89Yu5s7vysbyWncnZchY=";
        allowedIPs = [ "10.0.0.0/24" ];
        endpoint = "5.231.118.254:51820";
        persistentKeepalive = 25;
      }
    ];
  };

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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.tlp.enable = true;
  services.mullvad-vpn.enable = true;
  services.udisks2.enable = true;
  programs.hyprland.enable = true;
  programs.fish.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "home";
    };
  };
  
  users.users.cat = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" ];
    shell = pkgs.fish;
  };

  environment.systemPackages = with pkgs; [
    neovim
    git
    kitty
    wl-clipboard
    libnotify
    quickshell
    awww
    hyprshot
    hyprpolkitagent
    wireguard-tools
    kdePackages.breeze
    kdePackages.qtsvg
    imv
    mpv
    wiremix
    zathura
  ];

  fonts.packages = with pkgs; [
    cherry
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  documentation.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "26.05";
}
