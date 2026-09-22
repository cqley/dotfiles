{ config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "@cat4.org";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."git.cat4.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8888";
    };
    virtualHosts."files.cat4.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:47291";
    };
    virtualHosts."music.cat4.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:4533";
    };
    virtualHosts."tv.cat4.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8934";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}