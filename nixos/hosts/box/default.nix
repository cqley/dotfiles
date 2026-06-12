{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "box";
  networking.networkmanager.enable = true;

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    useOSProber = true;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services.getty.autologinUser = "cat";
  services.fstrim.enable = true;

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
  programs.dconf.enable = true;
  programs.steam.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    kitty
    wl-clipboard
    awww
    libnotify
    pywal
    quickshell
    grim
    slurp
    kdePackages.dolphin
    kdePackages.ark
    imv
    mpv
    obs-studio
    prismlauncher
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

  system.stateVersion = "26.05";
}
