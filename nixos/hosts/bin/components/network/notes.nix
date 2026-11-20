{ config, bin, ... }:

let
  notes = bin.go "notes" ./notes;
in
{
  network.services.notes = {
    site = "notes";
    data.notes = "/var/lib/notes";
  };

  systemd.sockets.notes = bin.socket [ "/run/notes.sock" ];

  systemd.services.notes = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "notes.socket" ];
    after = [ "notes.socket" ];
    environment = {
      NOTES_DIR = "/var/lib/notes";
      NOTES_ORIGINS = config.network.origins.notes;
    };
    serviceConfig = bin.sandbox // {
      ExecStart = "${notes}/bin/notes";
      DynamicUser = true;
      StateDirectory = "notes";
      WorkingDirectory = "/var/lib/notes";
      Restart = "on-failure";
      PrivateNetwork = true;
      IPAddressDeny = "any";
      RestrictAddressFamilies = [ "AF_UNIX" ];
      MemoryDenyWriteExecute = true;
      SystemCallFilter = [ "@system-service" "~@privileged" ];
    };
  };

  services.nginx.virtualHosts."notes" = {
    extraConfig = "client_max_body_size 10m;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://unix:/run/notes.sock";
  };
}
