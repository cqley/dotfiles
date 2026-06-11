{ ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "bin";
  
  services.openssh.enable = true;
  services.pufferpanel.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 8080 5657 ];

  users.users.cat.openssh.authorizedKeys.keys = [
    ""
  ];

  system.stateVersion = "26.05";
}
