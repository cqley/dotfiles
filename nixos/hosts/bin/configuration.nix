{ config, lib, pkgs, pkgs-unstable, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
    ./components/nginx.nix
    ./components/wireguard.nix
    ./components/dashboard.nix
    ./components/git.nix
    ./components/panel.nix
    ./components/blog.nix
    ./components/music.nix
    ./components/filehost.nix
    ../../modules/system/core.nix
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

}
