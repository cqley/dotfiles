{ config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "cat@1f2t.org";
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
    virtualHosts."host.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      extraConfig = "client_max_body_size 250M;";
      locations."/".proxyPass = "http://127.0.0.1:47291";
    };
    virtualHosts."tv.1f2t.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:8934";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
