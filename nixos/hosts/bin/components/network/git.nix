{ config, lib, pkgs, ... }:

let
  root = "/var/lib/git";
  host = "git.1f2t.org";

  users = {
    cat = config.users.users.cat.openssh.authorizedKeys.keys ++ [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDkDAmlLKbnBLZ3VOaz4dpMrVgDejUUe0bLaXO2KBEiO cat@bin"
    ];
  };

  path = lib.makeBinPath [ pkgs.git pkgs.coreutils pkgs.gnused pkgs.gawk ];
  script = name: pkgs.writeScript name (builtins.replaceStrings [ "#!/bin/sh\n" ] [ ''
    #!${pkgs.dash}/bin/dash
    PATH=${path}
    GITROOT=${root}
    GITHOST=${host}
    GITSSH=bin
  '' ] (builtins.readFile ./git/${name}.sh));

  ssh = script "ssh";
  web = script "web";

  fcgi = ''
    client_max_body_size 100m;
    fastcgi_read_timeout 300s;
    include ${config.services.nginx.package}/conf/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME ${web};
    fastcgi_param PATH_INFO $uri;
    fastcgi_pass unix:${config.services.fcgiwrap.instances.git.socket.address};
  '';
in
{
  users.groups.git = { };

  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = root;
    createHome = true;
    homeMode = "750";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = lib.concatLists (lib.mapAttrsToList
      (name: keys: map (key: ''command="${ssh} ${name}",restrict ${key}'') keys)
      users);
  };

  users.users.gitweb = {
    isSystemUser = true;
    group = "git";
  };

  services.fcgiwrap.instances.git = {
    process.prefork = 4;
    process.user = "gitweb";
    process.group = "git";
    socket.user = config.services.nginx.user;
    socket.group = config.services.nginx.group;
  };

  systemd.services.fcgiwrap-git.serviceConfig = {
    PrivateNetwork = true;
    IPAddressDeny = "any";
    RestrictAddressFamilies = "AF_UNIX";
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" "~@privileged" ];
    NoExecPaths = "/";
    ExecPaths = "/nix/store";
    MemoryMax = "1G";
  };

  systemd.services.gittrash = {
    startAt = "daily";
    serviceConfig = {
      Type = "oneshot";
      User = "git";
      Group = "git";
      ProtectSystem = "strict";
      ReadWritePaths = root;
      PrivateNetwork = true;
      NoNewPrivileges = true;
    };
    path = [ pkgs.findutils ];
    script = ''
      [ -d ${root}/.trash ] || exit 0
      find ${root}/.trash -mindepth 2 -maxdepth 2 -name '*.git' -mtime +6 -exec rm -rf {} +
    '';
  };

  services.nginx.appendHttpConfig = ''
    limit_req_zone $binary_remote_addr zone=githeavy:1m rate=1r/s;
    fastcgi_cache_path /var/cache/nginx/git levels=1:2 keys_zone=git:10m max_size=256m inactive=1d use_temp_path=off;
  '';

  services.nginx.virtualHosts.${host} = {
    forceSSL = true;
    enableACME = true;

    locations."= /git.css".alias = "${./git/git.css}";
    locations."= /git.js".alias = "${./git/git.js}";
    locations."/assets/".alias = "/etc/assets/";
    locations."= /robots.txt".extraConfig = ''
      default_type text/plain;
      return 200 "User-agent: *\nDisallow: /*/*/archive/\nDisallow: /*/*/commit/\nDisallow: /*/*/commits/\nDisallow: /*/*/files/\nDisallow: /*/*/raw/\n";
    '';

    locations."/".extraConfig = fcgi + ''
      fastcgi_cache git;
      fastcgi_cache_key $request_method$host$request_uri;
      fastcgi_ignore_headers Cache-Control Expires;
      fastcgi_cache_valid 200 5s;
      fastcgi_cache_revalidate on;
      fastcgi_cache_use_stale updating;
    '';
    locations."~ ^/[^/]+/[^/]+/(archive/|info/refs$|git-upload-pack$)".extraConfig = ''
      limit_req zone=githeavy burst=20 nodelay;
      limit_req_status 429;
      ${fcgi}
    '';
  };
}
