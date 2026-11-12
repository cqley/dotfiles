{ pkgs, ... }:

let
  keys = "/var/lib/linxkey";
  filehost = pkgs.callPackage ./filehost/package.nix { };
in
{
  systemd.services.linxkey = {
    path = [ pkgs.coreutils pkgs.gnused pkgs.linx-server ];
    script = ''
      umask 077
      [ -s ${keys}/key ] || head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > ${keys}/key
      printf '%s\n' "$(linx-genkey < ${keys}/key | sed 's/.*: //')" > ${keys}/authfile
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "linxkey";
      StateDirectoryMode = "0700";
    };
  };

  systemd.services.linx = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "linxkey.service" ];
    requires = [ "linxkey.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 127.0.0.1:47291 -siteurl https://share.1f2t.org/ -filespath /var/lib/linx/files -metapath /var/lib/linx/meta -maxsize 262144000 -authfile %d/authfile -basicauth";
      LoadCredential = [ "authfile:${keys}/authfile" ];
      WorkingDirectory = "/var/lib/linx";
      StateDirectory = "linx";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  systemd.services.filehost = {
    wantedBy = [ "multi-user.target" ];
    after = [ "linx.service" ];
    environment = {
      LINX_DIR = "/var/lib/linx";
      FILEHOST_ADDR = "127.0.0.1:4601";
    };
    serviceConfig = {
      ExecStart = "${filehost}/bin/filehost";
      DynamicUser = true;
      Restart = "on-failure";
      BindPaths = [ "/var/lib/linx" ];
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" "CAP_DAC_OVERRIDE" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" "CAP_DAC_OVERRIDE" ];
    };
  };

  services.nginx.virtualHosts."share.1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    extraConfig = ''
      client_max_body_size 300M;
      client_body_timeout 300s;
    '';

    locations."/assets/".alias = "/etc/assets/";

    locations."/API/".return = "404";

    locations."/" = {
      proxyPass = "http://127.0.0.1:47291";
      extraConfig = ''
        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
        sub_filter "<link href='/static/images/favicon.gif' rel='icon' type='image/gif'>" "";
        sub_filter "<title>" "<title>分</title><!--";
        sub_filter "</title>" "-->";
        sub_filter "</head>" "<link rel='stylesheet' href='/assets/linx.css'><script src='/assets/theme.js'></script></head>";
        sub_filter "initial-scale=0.8" "initial-scale=1";
        sub_filter '<a href="/paste/">Paste</a> |' '<a href="/paste/">Paste</a><!--';
        sub_filter '<a href="/API/">API</a>' '-->';
        sub_filter_once on;
      '';
    };
  };

  services.nginx.virtualHosts."filehost" = {
    listen = [{ addr = "10.0.0.1"; port = 8093; }];
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://127.0.0.1:4601";
  };
}
