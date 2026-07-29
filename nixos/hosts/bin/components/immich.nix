{
  networking.firewall.allowedTCPPorts = [ 2283 ];

  services.immich = {
    enable = true;
    host = "10.0.0.1";
    port = 2283;
    mediaLocation = "/var/lib/immich";
  };
}
