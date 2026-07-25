{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.3/24" ];
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      {
        publicKey = "W4Je63gh8f6LsSZfIj8PT7x0ktp9+dyDkPNBqvAmBUs=";
        endpoint = "5.231.118.254:51820";
        allowedIPs = [ "10.0.0.0/24" ];
        persistentKeepalive = 25;
      }
    ];
  };
}
