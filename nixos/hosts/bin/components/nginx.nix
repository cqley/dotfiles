{ config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "@1f2t.org";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."git.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8888";
    };
    virtualHosts."host.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:47291";
    };
    virtualHosts."music.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:4533";
    };
    virtualHosts."tv.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8934";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
