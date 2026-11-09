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
    serverTokens = false;

    appendHttpConfig = ''
      add_header Strict-Transport-Security "max-age=31536000" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "same-origin" always;
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
