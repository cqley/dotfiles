{ pkgs-unstable, ... }:

{
  disabledModules = [ "services/web-apps/immich.nix" ];
  imports = [ "${pkgs-unstable.path}/nixos/modules/services/web-apps/immich.nix" ];

  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;
    host = "127.0.0.1";
    machine-learning.enable = false;
  };

  network.services.immich = {
    units = [ "immich-server.service" ];
    site = "immich";
    data.photos = "/var/lib/immich";
  };

  services.nginx.virtualHosts."immich" = {
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
