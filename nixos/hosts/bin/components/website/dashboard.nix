{ pkgs, ... }:

{
  users.users.dash = {
    isSystemUser = true;
    group = "dash";
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.dash = {};

  systemd.services.dash-fast = {
    script = builtins.readFile ./sites/dashboard/fast.sh;
    path = [ pkgs.systemd pkgs.coreutils pkgs.gawk ];
    serviceConfig = {
      Type = "oneshot";
      User = "dash";
      Group = "dash";
      StateDirectory = "dash";
      StateDirectoryMode = "0755";
    };
  };
  systemd.timers.dash-fast = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "10s";
    };
  };

  systemd.services.dash-slow = {
    script = builtins.readFile ./sites/dashboard/slow.sh;
    path = [ pkgs.coreutils ];
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
  systemd.timers.dash-slow = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  environment.etc."dash/index.html".source = ./sites/dashboard/dashboard.html;

  services.nginx.virtualHosts."dash" = {
    listen = [{ addr = "10.0.0.1"; port = 8081; }];
    root = "/etc/dash";
    locations."/data/".alias = "/var/lib/dash/";
    locations."/assets/".alias = "/etc/website-assets/";
  };
}
