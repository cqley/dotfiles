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
    device = "/dev/sda";
  };
  
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };
  
  networking.hostName = "bin";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 25565 ];
    allowedUDPPorts = [ 51820 ];
    trustedInterfaces = [ "wg0" ];
  };

  networking.useDHCP = false;
  networking.interfaces.ens18.ipv4.addresses = [{
    address = "5.231.118.254";
    prefixLength = 24;
  }];
  networking.defaultGateway = {
    address = "5.231.118.1";
    interface = "ens18";
  };
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      {
        publicKey = "BdQ1JoAFU5XGFfZDNPEUk78zI8yLLReSWdVbeETwNX4=";
        allowedIPs = [ "10.0.0.2/32" ];
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
  programs.fish.enable = true;

  users.users.cat = {
    isNormalUser = true;
    description = "cat";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJq3Lw3QReo6e9S1jbt1AywvaLKfgTY/GagPsfReP+t cat@box"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    wireguard-tools
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.pufferpanel = {
    enable = true;
    extraPackages = [
      pkgs.jdk25
      (pkgs.writeShellScriptBin "java25" "exec ${pkgs.jdk25}/bin/java \"$@\"")
    ];
    environment = {
      PUFFER_WEB_HOST = "10.0.0.1:8080";
      PUFFER_DAEMON_SFTP_HOST = "10.0.0.1:5657";
    };
  };

  systemd.services.pocketbase = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.pocketbase}/bin/pocketbase serve --http=10.0.0.1:8090 --dir=/var/lib/pocketbase --publicDir=/var/lib/pocketbase/pb_public";
      Restart = "no";
    };
  };

  documentation.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "26.05";
}
