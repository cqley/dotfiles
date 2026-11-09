{ pkgs, ... }:

let
  uploadKeys = pkgs.writeText "filehostkeys" "0bmKIN8r1/L4fr8npo3V9+fdDepx7d43weGOqKzQh6c=\n";
in
{
  systemd.services.linx = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 127.0.0.1:47291 -siteurl https://host.1f2t.org/ -filespath /var/lib/linx/files -metapath /var/lib/linx/meta -maxsize 262144000 -authfile ${uploadKeys} -basicauth";
      WorkingDirectory = "/var/lib/linx";
      StateDirectory = "linx";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  systemd.services.filehost = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/filehost/.deno";
    script = ''
      exec ${pkgs.deno}/bin/deno run --no-prompt --allow-net=127.0.0.1:4601 --allow-read=/var/lib/linx,/var/lib/filehost --allow-write=/var/lib/linx,/var/lib/filehost --allow-env=STATE_DIRECTORY ${./sites/filehost/server.js}
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "filehost";
      WorkingDirectory = "/var/lib/filehost";
      Restart = "on-failure";
      BindPaths = [ "/var/lib/linx" ];
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

    locations."/assets/".alias = "/etc/assets/";

    locations."/dashboard".proxyPass = "http://127.0.0.1:4601";

    locations."/" = {
      proxyPass = "http://127.0.0.1:47291";
      extraConfig = ''
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        sub_filter "<link href='/static/images/favicon.gif' rel='icon' type='image/gif'>" "<link href='/assets/cat.svg' rel='icon' type='image/svg+xml'>";
        sub_filter "<title>" "<title>分</title><!--";
        sub_filter "</title>" "-->";
        sub_filter "</head>" "<link rel='stylesheet' href='/assets/linx.css'></head>";
        sub_filter "initial-scale=0.8" "initial-scale=1";
        sub_filter_once on;
      '';
    };
  };
}
