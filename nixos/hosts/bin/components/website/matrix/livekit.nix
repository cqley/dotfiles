{ pkgs, ... }:

let
  livekitSecret = "3d140dfc749bead29137610391c2d6d30f5e34d09e52d99cf1680557fae56726";
  livekitKeyFile = pkgs.writeText "livekitkeys.yaml" "tuwunel: ${livekitSecret}\n";
in
{
  services.livekit = {
    enable = true;
    keyFile = livekitKeyFile;
    settings = {
      port = 7880;
      rtc = {
        tcp_port = 7881;
        port_range_start = 50000;
        port_range_end = 51000;
        use_external_ip = false;
        node_ip = "5.231.118.153";
      };
      room.auto_create = false;
    };
  };

  services.lk-jwt-service = {
    enable = true;
    livekitUrl = "wss://livekit.1f2t.org";
    keyFile = livekitKeyFile;
    port = 8082;
  };

  systemd.services.lk-jwt-service.environment = {
    LIVEKIT_JWT_BIND = pkgs.lib.mkForce "127.0.0.1:8082";
    LIVEKIT_FULL_ACCESS_HOMESERVERS = "matrix.1f2t.org";
  };

  services.nginx.virtualHosts."livekit.1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    locations."~ ^/(sfu/get|healthz|get_token)" = {
      proxyPass = "http://127.0.0.1:8082";
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:7880";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 7881 ];
  networking.firewall.allowedUDPPortRanges = [{ from = 50000; to = 51000; }];
}
