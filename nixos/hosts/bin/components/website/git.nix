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
  '' ] (builtins.readFile ./git/${name}.sh));

  ssh = script "ssh";
  web = script "web";
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

  services.nginx.virtualHosts.${host} = {
    forceSSL = true;
    enableACME = true;

    locations."= /git.css".alias = "${./git/git.css}";
    locations."= /git.js".alias = "${./git/git.js}";
    locations."/assets/".alias = "/etc/assets/";

    locations."/".extraConfig = ''
      client_max_body_size 100m;
      fastcgi_read_timeout 300s;
      include ${config.services.nginx.package}/conf/fastcgi_params;
      fastcgi_param SCRIPT_FILENAME ${web};
      fastcgi_param PATH_INFO $uri;
      fastcgi_pass unix:${config.services.fcgiwrap.instances.git.socket.address};
    '';
  };
}
