{ pkgs, ... }:

let
  notes = pkgs.callPackage ./notes/package.nix { };
in
{
  systemd.services.notes = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment = {
      NOTES_DIR = "/var/lib/notes";
      NOTES_ADDR = "127.0.0.1:4605";
    };
    serviceConfig = {
      ExecStart = "${notes}/bin/notes";
      DynamicUser = true;
      StateDirectory = "notes";
      WorkingDirectory = "/var/lib/notes";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  services.nginx.virtualHosts."notes" = {
    listen = [{ addr = "10.0.0.1"; port = 8091; }];
    extraConfig = "client_max_body_size 10m;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://127.0.0.1:4605";
  };
}
