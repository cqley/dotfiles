{ ... }:

{
  services.coturn = {
    enable = true;
    realm = "matrix.1f2t.org";
    use-auth-secret = true;
    static-auth-secret-file = "/run/credentials/coturn.service/turn";
    cert = "/var/lib/acme/matrix.1f2t.org/fullchain.pem";
    pkey = "/var/lib/acme/matrix.1f2t.org/key.pem";
    no-cli = true;
    extraConfig = ''
      no-multicast-peers
      denied-peer-ip=0.0.0.0-0.255.255.255
      denied-peer-ip=10.0.0.0-10.255.255.255
      denied-peer-ip=100.64.0.0-100.127.255.255
      denied-peer-ip=127.0.0.0-127.255.255.255
      denied-peer-ip=169.254.0.0-169.254.255.255
      denied-peer-ip=172.16.0.0-172.31.255.255
      denied-peer-ip=192.0.0.0-192.0.0.255
      denied-peer-ip=192.168.0.0-192.168.255.255
      denied-peer-ip=198.18.0.0-198.19.255.255
      denied-peer-ip=::1
      denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
    '';
    min-port = 51001;
    max-port = 65535;
  };

  users.users.turnserver.extraGroups = [ "nginx" ];

  security.acme.certs."matrix.1f2t.org".reloadServices = [ "coturn.service" ];

  networking.firewall.allowedTCPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPortRanges = [{ from = 51001; to = 65535; }];
}
