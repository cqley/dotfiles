{ pkgs, ... }:
{
  systemd.services.linx-server = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.linx-server}/bin/linx-server -bind 0.0.0.0:47291 -siteurl http://5.231.118.153:47291/ -maxsize 1073741824 -filespath /var/lib/linx-server/files -metapath /var/lib/linx-server/meta";
      DynamicUser = true;
      StateDirectory = "linx-server linx-server/files linx-server/meta";
    };
  };

  networking.firewall.allowedTCPPorts = [ 47291 ];
}
