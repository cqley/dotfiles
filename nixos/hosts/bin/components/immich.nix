{ pkgs-unstable, ... }:

{
  disabledModules = [ "services/web-apps/immich.nix" ];
  imports = [ "${pkgs-unstable.path}/nixos/modules/services/web-apps/immich.nix" ];

  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;
    host = "127.0.0.1";
  };

  services.nginx.virtualHosts."immich" = {
    listen = [{ addr = "10.0.0.1"; port = 2283; }];
    extraConfig = ''
      client_max_body_size 50000M;
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
      send_timeout 600s;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
    };
  };
}
