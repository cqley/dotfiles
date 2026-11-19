{ pkgs, ... }:

let
  share = pkgs.callPackage ./share/package.nix { };
in
{
  systemd.services.sharekey = {
    path = [ pkgs.coreutils ];
    script = ''
      umask 077
      [ -s /var/lib/sharekey/key ] || head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > /var/lib/sharekey/key
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "sharekey";
      StateDirectoryMode = "0700";
    };
  };

  systemd.sockets.share = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/share.sock" "/run/sharedash.sock" ];
    socketConfig = {
      SocketUser = "nginx";
      SocketGroup = "nginx";
      SocketMode = "0600";
    };
  };

  systemd.services.share = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "share.socket" "sharekey.service" ];
    after = [ "share.socket" "sharekey.service" ];
    environment = {
      SHARE_DIR = "/var/lib/share";
      SHARE_URL = "https://share.1f2t.org/";
      SHARE_DASH_ORIGINS = "http://10.0.0.1:8093 http://bin:8093";
    };
    serviceConfig = {
      ExecStart = "${share}/bin/share";
      LoadCredential = [ "key:/var/lib/sharekey/key" ];
      DynamicUser = true;
      StateDirectory = "share";
      UMask = "0077";
      Restart = "on-failure";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      IPAddressDeny = [ "localhost" "link-local" "multicast" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10" "fc00::/7" "5.231.118.153" "2a14:7c0:1002:1307::/64" ];
      MemoryMax = "1G";
      NoExecPaths = [ "/" ];
      ExecPaths = [ "/nix/store" ];
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
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
    listen = [{ addr = "10.0.0.1"; port = 8093; }];
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://unix:/run/sharedash.sock";
  };
}
