{
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.firewall.trustedInterfaces = [ "wg0" ];
  
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/var/lib/wireguard/privatekey";

    peers = [
      # PC
      {
        publicKey = "BdQ1JoAFU5XGFfZDNPEUk78zI8yLLReSWdVbeETwNX4=";
        allowedIPs = [ "10.0.0.2/32" ];
      }
      # Laptop
      {
        publicKey = " ";
        allowedIPs = [ "10.0.0.3/32" ];
      }
    ];
  };
}
