{ pkgs, ... }:
{
  systemd.services.linx-server = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 127.0.0.1:47291 -siteurl https://host.1f2t.org/ -filespath /var/lib/linx-server/files -metapath /var/lib/linx-server/meta -maxsize 262144000";
      WorkingDirectory = "/var/lib/linx-server";
      StateDirectory = "linx-server";
      DynamicUser = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 47291 ];
}
