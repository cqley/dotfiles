{ pkgs, ... }:
{
  systemd.services.linx-server = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 127.0.0.1:47291 -siteurl https://host.1f2t.org/ -filespath /var/lib/linx-server/files -metapath /var/lib/linx-server/meta -maxsize 262144000";
      WorkingDirectory = "/var/lib/linx-server";
      StateDirectory = "linx-server";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  systemd.services.filehost-dashboard = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/filehost-dashboard/.deno";
    script = ''
      exec ${pkgs.deno}/bin/deno run --allow-net --allow-read --allow-write --allow-env ${./sites/filehost-dashboard/server.js}
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "filehost-dashboard";
      WorkingDirectory = "/var/lib/filehost-dashboard";
      Restart = "on-failure";
      BindPaths = [ "/var/lib/linx-server" ];
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" "CAP_DAC_OVERRIDE" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" "CAP_DAC_OVERRIDE" ];
    };
  };

  services.nginx.virtualHosts."host.1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    extraConfig = ''
      client_max_body_size 300M;
      client_body_timeout 300s;
    '';

    locations."/assets/".alias = "/etc/website-assets/";

    locations."/dashboard".proxyPass = "http://127.0.0.1:4601";

    locations."/" = {
      proxyPass = "http://127.0.0.1:47291";
      extraConfig = ''
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        sub_filter "<link href='/static/images/favicon.gif' rel='icon' type='image/gif'>" "<link href='/assets/cat.svg' rel='icon' type='image/svg+xml'>";
        sub_filter_once on;
      '';
    };
  };
}
