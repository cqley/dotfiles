{ ... }:

{
  services.nginx.virtualHosts."matrix.1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    locations."/_matrix/" = {
      proxyPass = "http://127.0.0.1:6167";
      extraConfig = ''
        client_max_body_size 20m;
        proxy_read_timeout 300s;
      '';
    };

    locations."/.well-known/matrix/" = {
      proxyPass = "http://127.0.0.1:6167";
      extraConfig = ''
        add_header Access-Control-Allow-Origin "*" always;
        add_header Strict-Transport-Security "max-age=31536000" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header Referrer-Policy "same-origin" always;
      '';
    };

    locations."/" = {
      return = "404";
    };
  };
}