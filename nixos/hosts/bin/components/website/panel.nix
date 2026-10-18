{ pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [ 25565 5657 ];

  services.pufferpanel = {
    enable = true;
    extraPackages = [
      pkgs.jdk25
      (pkgs.writeShellScriptBin "java25" "exec ${pkgs.jdk25}/bin/java \"$@\"")
    ];
    environment = {
      PUFFER_WEB_HOST = "127.0.0.1:8080";
      PUFFER_DAEMON_SFTP_HOST = "0.0.0.0:5657";
    };
  };

  services.nginx.virtualHosts."panel.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
    };
  };
}
