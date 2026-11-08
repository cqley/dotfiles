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
        port_range_start = 50000;
        port_range_end = 51000;
      };
    };
  };

  services.lk-jwt-service = {
    enable = true;
    livekitUrl = "wss://livekit.1f2t.org";
    keyFile = livekitKeyFile;
    port = 8082;
  };

  services.nginx.virtualHosts."livekit.1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    locations."/sfu/" = {
      proxyPass = "http://127.0.0.1:8082";
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:7880";
      proxyWebsockets = true;
    };
  };

  networking.firewall.allowedUDPPortRanges = [{ from = 50000; to = 51000; }];
}