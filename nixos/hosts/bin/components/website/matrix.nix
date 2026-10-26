{ ... }:
{
  services.matrix-tuwunel = {
    enable = true;

    settings.global = {
      server_name = "matrix.1f2t.org";
      allow_registration = true;
      registration_token = "YWvscPJI3dkE6PLkwRvNZ2wPyhxvUUJl";
      allow_federation = true;
      allow_encryption = true;
    };
  };

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
  };
}
