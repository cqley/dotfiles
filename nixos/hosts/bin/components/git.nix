{
  services.cgit.1f2t = {
    enable = true;
    scanPath = "/srv/git";
    nginx.virtualHost = "git.1f2t.org";
    gitHttpBackend = {
      enable = true;
      checkExportOkFiles = false;
    };
    settings = {
      root-title = "1f2t";
      root-desc = "";
      enable-index-owner = 0;
      enable-commit-graph = 1;
      enable-log-filecount = 1;
      enable-log-linecount = 1;
      clone-prefix = "https://git.1f2t.org";
    };
  };
}