{ pkgs, bin, ... }:

let
  aiostreams = pkgs.callPackage ./aiostreams/package.nix { };
in
{
  network.services.aiostreams = {
    site = "aiostreams";
    data.aiostreams = "/var/lib/aiostreams";
  };

  systemd.services.aiostreamskey = bin.secret "aiostreamskey" "[ -s key ] || gen 32 > key";

  systemd.sockets.aiostreams = bin.socket [ "/run/aiostreams.sock" ];

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
    serviceConfig = bin.sandbox // {
      LoadCredential = [ "key:/var/lib/aiostreamskey/key" ];
      DynamicUser = true;
      StateDirectory = "aiostreams";
      WorkingDirectory = "/var/lib/aiostreams";
      UMask = "0077";
      Restart = "on-failure";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      IPAddressAllow = [ "10.0.0.1" ];
      IPAddressDeny = bin.outside;
      MemoryMax = "2G";
      NoExecPaths = [ "/" ];
      ExecPaths = [ "/nix/store" ];
    };
  };

  services.nginx.virtualHosts."aiostreams" = {
    extraConfig = ''
      if ($http_sec_fetch_site = cross-site) { return 403; }
    '';
    locations."/" = {
      proxyPass = "http://unix:/run/aiostreams.sock";
      proxyWebsockets = true;
    };
  };
}
