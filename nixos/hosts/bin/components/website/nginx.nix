{ ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "cat@1f2t.org";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    clientMaxBodySize = "10m";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
