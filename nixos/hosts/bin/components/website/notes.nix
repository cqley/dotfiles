{ pkgs, ... }:

let
  notes = pkgs.callPackage ./notes/package.nix { };
in
{
  systemd.sockets.notes = {
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "/run/notes.sock" ];
    socketConfig = {
      SocketUser = "nginx";
      SocketGroup = "nginx";
      SocketMode = "0600";
    };
  };

  systemd.services.notes = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "notes.socket" ];
    after = [ "notes.socket" ];
    environment = {
      NOTES_DIR = "/var/lib/notes";
      NOTES_ORIGINS = "http://10.0.0.1:8091 http://bin:8091";
    };
    serviceConfig = {
      ExecStart = "${notes}/bin/notes";
      DynamicUser = true;
      StateDirectory = "notes";
      WorkingDirectory = "/var/lib/notes";
      Restart = "on-failure";
      PrivateNetwork = true;
      IPAddressDeny = "any";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  services.nginx.virtualHosts."notes" = {
    listen = [{ addr = "10.0.0.1"; port = 8091; }];
    extraConfig = "client_max_body_size 10m;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://unix:/run/notes.sock";
  };
}
