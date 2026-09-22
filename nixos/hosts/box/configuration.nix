{ config, pkgs, pkgs-unstable, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
    ./components/wireguard.nix
    ../../modules/misc/core.nix
    ../../modules/misc/public.nix
    ../../modules/misc/ariang.nix
  ];
  
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    useOSProber = true;
  };
  boot.kernelPackages = pkgs.linuxPackages;

  services.getty.autologinUser = "cat";
  services.fstrim.enable = true;
  
  networking.hostName = "box";
  networking.networkmanager.enable = true;

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

  services.udisks2.enable = true;
  programs.hyprland.enable = true;
  programs.fish.enable = true;
  programs.dconf.enable = true;
  programs.steam.enable = true;
  programs.steam.extraCompatPackages = with pkgs; [
    proton-ge-bin
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "3554:fa09" ];
      settings.main.capslock = "home";
    };
  };

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "networkmanager" "wheel" "input" ];
    shell = pkgs.fish;
  };

environment.systemPackages = with pkgs; [
    git
    kitty
    tmux
    wl-clipboard
    libnotify
    quickshell
    awww
    hyprshot
    hyprpolkitagent
    wireguard-tools
    imv
    mpv
    wiremix
    zathura
    libreoffice
    kdePackages.kdenlive
  ];

fonts.packages = with pkgs; [
  cherry
  noto-fonts
  noto-fonts-cjk-sans
  noto-fonts-color-emoji
  nerd-fonts.jetbrains-mono
];

}
