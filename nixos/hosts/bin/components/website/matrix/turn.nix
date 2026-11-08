{ ... }:

{
  services.coturn = {
    enable = true;
    realm = "matrix.1f2t.org";
    use-auth-secret = true;
    static-auth-secret = "4626905729e91d52d10c68a9e31499c8f595270d87c9b898a187c0d98080f3ef";
    cert = "/var/lib/acme/matrix.1f2t.org/fullchain.pem";
    pkey = "/var/lib/acme/matrix.1f2t.org/key.pem";
    no-cli = true;
  };

  users.users.turnserver.extraGroups = [ "nginx" ];

  security.acme.certs."matrix.1f2t.org".reloadServices = [ "coturn.service" ];

  networking.firewall.allowedTCPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPortRanges = [{ from = 49152; to = 65535; }];
}