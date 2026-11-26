{
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.firewall.trustedInterfaces = [ "wg0" ];

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  networking.firewall.extraCommands = ''
    iptables -w -N mesh 2>/dev/null || iptables -w -F mesh
    iptables -w -A mesh -i wg0 -o wg0 -s 10.0.0.0/24 -d 10.0.0.0/24 -j ACCEPT
    iptables -w -A mesh -j DROP
    iptables -w -D FORWARD -j mesh 2>/dev/null || true
    iptables -w -I FORWARD -j mesh
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D FORWARD -j mesh 2>/dev/null || true
  '';

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/var/lib/wireguard/privatekey";
    postSetup = "echo 1 > /proc/sys/net/ipv4/conf/wg0/forwarding";

    peers = [
      {
        publicKey = "BdQ1JoAFU5XGFfZDNPEUk78zI8yLLReSWdVbeETwNX4=";
        allowedIPs = [ "10.0.0.2/32" ];
      }
      {
        publicKey = "W4Je63gh8f6LsSZfIj8PT7x0ktp9+dyDkPNBqvAmBUs=";
        allowedIPs = [ "10.0.0.3/32" ];
      }
      {
        publicKey = "1/DLSTPP53MrhoETEf308ZInfs39z74S8zpzEHoPvGk=";
        allowedIPs = [ "10.0.0.4/32" ];
      }
    ];
  };
}
