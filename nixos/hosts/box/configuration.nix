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
  
  networking.hostName = "box";
  networking.networkmanager.enable = true;
  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.2/24" ];
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

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaSettings = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  programs.hyprland.enable = true;
  programs.fish.enable = true;
  programs.dconf.enable = true;
  programs.steam.enable = true;
  services.udisks2.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "home";
    };
  };

environment.systemPackages = with pkgs; [
    btop
    git
    kitty
    wl-clipboard
    libnotify
    quickshell
    awww
    hyprshot
    hyprpolkitagent
    wireguard-tools
    yazi
    kdePackages.breeze
    kdePackages.qtsvg
    imv
    mpv
    wiremix
    obsidian
  ];

  fonts.packages = with pkgs; [
    corefonts
    noto-fonts
    noto-fonts-cjk-sans
    google-fonts
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    twemoji-color-font
  ];

documentation.enable = false;
documentation.man.enable = false;

  system.stateVersion = "26.05";
}
