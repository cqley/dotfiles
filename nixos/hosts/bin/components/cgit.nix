{
  networking.firewall.allowedTCPPorts = [ 8888 ];

  services.nginx = {
    enable = true;
    virtualHosts."cgit" = {
      listen = [
        {
          addr = "5.231.118.153";
          port = 8888;
        }
      ];
    };
  };

  services.cgit.tight = {
    enable = true;
    scanPath = "/srv/git";
    nginx.virtualHost = "cgit";
    gitHttpBackend = {
      enable = true;
      checkExportOkFiles = false;
    };
    settings = {
      root-title = "tight";
      root-desc = "";
      enable-index-owner = 0;
      enable-commit-graph = 1;
      enable-log-filecount = 1;
      enable-log-linecount = 1;
      clone-prefix = "http://5.231.118.153:8888";
    };
  };
}
