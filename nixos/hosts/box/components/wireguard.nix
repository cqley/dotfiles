{
  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.2/24" ];
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      {
        publicKey = "P2LPLBq/6qXE5Mmv8DJUviU89Yu5s7vysbyWncnZchY=";
        allowedIPs = [ "10.0.0.0/24" ];
        endpoint = "5.231.118.254:51820";
        persistentKeepalive = 25;
      }
    ];
  };
}
