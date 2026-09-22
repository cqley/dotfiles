{ pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 25565 ];
  
  services.pufferpanel = {
    enable = true;
    extraPackages = [
      pkgs.jdk25
      (pkgs.writeShellScriptBin "java25" "exec ${pkgs.jdk25}/bin/java \"$@\"")
    ];
    environment = {
      PUFFER_WEB_HOST = "10.0.0.1:8080";
      PUFFER_DAEMON_SFTP_HOST = "10.0.0.1:5657";
    };
  };
}
