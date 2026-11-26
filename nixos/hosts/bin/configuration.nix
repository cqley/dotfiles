{ config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./components/wireguard.nix
    ./components/security.nix
    ./components/immich.nix
    ./components/minecraft.nix
    ./components/network/nginx.nix
    ./components/network/services.nix
    ./components/network/assets.nix
    ./components/network/website.nix
    ./components/network/dashboard.nix
    ./components/network/matrix.nix
    ./components/network/blog.nix
    ./components/network/music.nix
    ./components/network/share.nix
    ./components/network/notes.nix
    ./components/network/git.nix
    ./components/streaming/jellyfin.nix
    ./components/streaming/aiostreams.nix
    ../../modules/system/core.nix
    ../../modules/system/names.nix
    ../../modules/system/editor.nix
    ../../modules/misc/public.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
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
    tmux
    dnsutils
    wireguard-tools
    ouch
    claude-code
    sox
  ];

  services.nscd.enable = false;
  services.journald.extraConfig = "SystemMaxUse=500M";
  services.syncthing.guiAddress = "/home/cat/.config/syncthing/gui.sock";
  system.nssModules = lib.mkForce [];

  programs.nix-ld.enable = true;

  services.openssh = {
    openFirewall = false;
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      ClientAliveInterval = 30;
      ClientAliveCountMax = 3;
    };
  };

}
