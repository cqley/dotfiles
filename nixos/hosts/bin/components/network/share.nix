{ config, bin, ... }:

let
  share = bin.go "share" ./share;
in
{
  network.services.share = {
    site = "share";
    data.files = "/var/lib/share";
  };

  systemd.services.sharekey = bin.secret "sharekey" "[ -s key ] || gen 24 > key";

  systemd.sockets.share = bin.socket [ "/run/share.sock" "/run/sharedash.sock" ];

  systemd.services.share = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "share.socket" "sharekey.service" ];
    after = [ "share.socket" "sharekey.service" ];
    environment = {
      SHARE_DIR = "/var/lib/share";
      SHARE_URL = "https://share.1f2t.org/";
      SHARE_DASH_ORIGINS = config.network.origins.share;
    };
    serviceConfig = bin.sandbox // {
      ExecStart = "${share}/bin/share";
      LoadCredential = [ "key:/var/lib/sharekey/key" ];
      DynamicUser = true;
      StateDirectory = "share";
      UMask = "0077";
      Restart = "on-failure";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      IPAddressDeny = bin.outside;
      MemoryMax = "1G";
      NoExecPaths = [ "/" ];
      ExecPaths = [ "/nix/store" ];
      MemoryDenyWriteExecute = true;
      SystemCallFilter = [ "@system-service" "~@privileged" ];
    };
  };

  services.nginx.appendHttpConfig = ''
    map "$request_method:$http_linx_access_key" $sharetry {
      "GET:" "";
      "HEAD:" "";
      default $binary_remote_addr;
    }
    limit_req_zone $sharetry zone=sharetry:1m rate=1r/s;
  '';

  services.nginx.virtualHosts."share.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      client_max_body_size 260m;
      client_body_timeout 300s;
      proxy_request_buffering off;
      proxy_buffering off;
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
    '';
    locations."/assets/".alias = "/etc/assets/";
    locations."= /upload".proxyPass = "http://unix:/run/share.sock";
    locations."/upload/".proxyPass = "http://unix:/run/share.sock";
    locations."/" = {
      proxyPass = "http://unix:/run/share.sock";
      extraConfig = ''
        limit_req zone=sharetry burst=10 nodelay;
        limit_req_status 429;
      '';
    };
  };

  services.nginx.virtualHosts."share" = {
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://unix:/run/sharedash.sock";
  };
}
