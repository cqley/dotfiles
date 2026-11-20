{ pkgs, ... }:

{
  users.users.dash = {
    isSystemUser = true;
    group = "dash";
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.dash = {};

  systemd.services.dashstatus = {
    script = builtins.readFile ./sites/dashboard/fast.sh;
    path = [ pkgs.systemd pkgs.coreutils pkgs.gawk pkgs.jq pkgs.openssh pkgs.wireguard-tools pkgs.getent ];
    serviceConfig = {
      Type = "oneshot";
      User = "dash";
      Group = "dash";
      StateDirectory = "dash";
      StateDirectoryMode = "0755";
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
    };
  };
  systemd.timers.dashstatus = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "10s";
    };
  };

  systemd.services.dashstorage = {
    script = builtins.readFile ./sites/dashboard/slow.sh;
    path = [ pkgs.coreutils pkgs.jq ];
    serviceConfig = {
      Type = "oneshot";
      User = "dash";
      Group = "dash";
      StateDirectory = "dash";
      StateDirectoryMode = "0755";
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    };
  };
  systemd.timers.dashstorage = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  environment.etc."dash/index.html".source = ./sites/dashboard/dashboard.html;
  environment.etc."dash/404.html".source = ./sites/dashboard/404.html;

  services.nginx.virtualHosts."dash" = {
    root = "/etc/dash";
    extraConfig = "error_page 404 /404.html;";
    locations."= /ca.crt" = {
      alias = "/var/lib/bincert/ca.crt";
      extraConfig = "default_type application/x-x509-ca-cert;";
    };
    locations."/data/".alias = "/var/lib/dash/";
    locations."/assets/".alias = "/etc/assets/";
  };
}
