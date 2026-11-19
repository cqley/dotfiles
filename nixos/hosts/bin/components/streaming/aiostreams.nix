{ pkgs, ... }:

let
  aiostreams = pkgs.callPackage ./aiostreams/package.nix { };
in
{
  systemd.services.aiostreamskey = {
    path = [ pkgs.coreutils ];
    script = ''
      umask 077
      [ -s /var/lib/aiostreamskey/key ] || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /var/lib/aiostreamskey/key
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "aiostreamskey";
      StateDirectoryMode = "0700";
    };
  };

  systemd.sockets.aiostreams = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/aiostreams.sock" ];
    socketConfig = {
      SocketUser = "nginx";
      SocketGroup = "nginx";
      SocketMode = "0600";
    };
  };

  systemd.services.aiostreams = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "aiostreams.socket" "aiostreamskey.service" ];
    after = [ "aiostreams.socket" "aiostreamskey.service" ];
    environment = {
      BASE_URL = "http://10.0.0.1:8095";
      INTERNAL_URL = "http://10.0.0.1:8095";
      REMUXDB_ENABLED = "false";
    };
    script = ''
      SECRET_KEY=$(cat "$CREDENTIALS_DIRECTORY/key") exec ${aiostreams}/bin/aiostreams
    '';
    serviceConfig = {
      LoadCredential = [ "key:/var/lib/aiostreamskey/key" ];
      DynamicUser = true;
      StateDirectory = "aiostreams";
      WorkingDirectory = "/var/lib/aiostreams";
      UMask = "0077";
      Restart = "on-failure";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      IPAddressAllow = [ "10.0.0.1" ];
      IPAddressDeny = [ "localhost" "link-local" "multicast" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10" "fc00::/7" "5.231.118.153" "2a14:7c0:1002:1307::/64" ];
      MemoryMax = "2G";
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
      CapabilityBoundingSet = "";
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  services.nginx.virtualHosts."aiostreams" = {
    listen = [{ addr = "10.0.0.1"; port = 8095; }];
    extraConfig = ''
      if ($http_sec_fetch_site = cross-site) { return 403; }
    '';
    locations."/" = {
      proxyPass = "http://unix:/run/aiostreams.sock";
      proxyWebsockets = true;
    };
  };
}
