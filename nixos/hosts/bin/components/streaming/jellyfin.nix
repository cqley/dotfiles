{ pkgs, pkgs-unstable, ... }:

let
  network = pkgs.writeText "network.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <AutoDiscovery>false</AutoDiscovery>
      <LocalNetworkSubnets>
        <string>10.0.0.0/24</string>
      </LocalNetworkSubnets>
      <LocalNetworkAddresses>
        <string>127.0.0.1</string>
      </LocalNetworkAddresses>
      <KnownProxies>
        <string>127.0.0.1</string>
      </KnownProxies>
    </NetworkConfiguration>
  '';
  proxy = {
    proxyPass = "http://127.0.0.1:8096";
    proxyWebsockets = true;
  };
  site = {
    extraConfig = ''
      proxy_buffering off;
      if ($http_sec_fetch_site = cross-site) { return 403; }
    '';
    locations."/" = proxy;
  };
in
{
  services.jellyfin = {
    enable = true;
    package = pkgs-unstable.jellyfin;
  };

  systemd.services.jellyfin = {
    preStart = "install -m 600 ${network} /var/lib/jellyfin/config/network.xml";
    serviceConfig = {
      CPUQuota = "500%";
      Nice = 10;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/media 2750 cat jellyfin -"
    "d /var/lib/jellyfin/gelato 0750 jellyfin jellyfin -"
    "d /var/lib/jellyfin/gelato/movies 0750 jellyfin jellyfin -"
    "d /var/lib/jellyfin/gelato/shows 0750 jellyfin jellyfin -"
  ];

  security.acme.certs."stream.1f2t.org".keyType = "rsa2048";

  services.nginx.appendHttpConfig = ''
    limit_req_zone $binary_remote_addr zone=jellylogin:1m rate=5r/m;
  '';

  services.nginx.virtualHosts."jellyfin" = site // {
    listen = [{ addr = "10.0.0.1"; port = 8096; }];
  };

  services.nginx.virtualHosts."stream.1f2t.org" = site // {
    forceSSL = true;
    enableACME = true;
    locations."/" = proxy;
    locations."~* ^/(users/(authenticatebyname|authenticatewithquickconnect|forgotpassword)|quickconnect/)" = proxy // {
      extraConfig = ''
        limit_req zone=jellylogin burst=5 nodelay;
        limit_req_status 429;
      '';
    };
  };
}
