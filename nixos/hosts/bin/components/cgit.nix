{
  services.nginx = {
    enable = true;
    virtualHosts."5.231.118.254" = {};
  };

  services.cgit.blind = {
    enable = true;
    scanPath = "/srv/git";
    nginx.virtualHost = "5.231.118.254";
    gitHttpBackend = {
      enable = true;
      checkExportOkFiles = false;
    };
    settings = {
      root-title = "blind";
      root-desc = "";
      enable-index-owner = 0;
      enable-commit-graph = 1;
      enable-log-filecount = 1;
      enable-log-linecount = 1;
      clone-prefix = "http://5.231.118.254";
    };
  };
}
