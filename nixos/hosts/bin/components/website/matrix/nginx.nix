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
      '';
    };

    locations."/" = {
      return = "404";
    };
  };
}