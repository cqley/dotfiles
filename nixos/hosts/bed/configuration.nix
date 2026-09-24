{ config, pkgs, pkgs-unstable, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
    ./components/wireguard.nix
    ../../modules/system/core.nix
    ../../modules/misc/public.nix
    ../../modules/misc/ariang.nix
  ];
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];

  services.getty.autologinUser = "cat";
  services.fstrim.enable = true;
  
  networking.hostName = "bed";
  networking.networkmanager.enable = true;

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

  services.udev.extraRules = ''KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"'';
  services.tlp.enable = true;
  services.udisks2.enable = true;
  programs.hyprland.enable = true;
  programs.fish.enable = true;
  programs.dconf.enable = true;
  hardware.uinput.enable = true;

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

  security.doas.enable = true;
  security.sudo.enable = false;
  security.doas.extraRules = [{
    users = ["cat"];
    keepEnv = true;
    persist = true;
  }];

  users.users.cat = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" "input" "uinput" ];
    shell = pkgs.fish;
  };

  environment.systemPackages = with pkgs; [
    git
    kitty
    tmux
    brave-origin
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
    brightnessctl
  ];

  fonts.packages = with pkgs; [
    cherry
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

}
