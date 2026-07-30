{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.3/24" ];
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      {
        publicKey = "P2LPLBq/6qXE5Mmv8DJUviU89Yu5s7vysbyWncnZchY=";
        endpoint = "5.231.118.153:51820";
        allowedIPs = [ "10.0.0.0/24" ];
        persistentKeepalive = 25;
      }
    ];
  };
}
