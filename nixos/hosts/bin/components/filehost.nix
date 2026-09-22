{ pkgs, ... }:
{
  systemd.services.linx-server = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 127.0.0.1:47291 -siteurl https://host.1f2t.org/ ...";
      DynamicUser = true;
      StateDirectory = "linx-server linx-server/files linx-server/meta";
    };
  };

  networking.firewall.allowedTCPPorts = [ 47291 ];
}
