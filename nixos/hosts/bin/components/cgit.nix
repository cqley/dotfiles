{
  services.cgit.tight = {
    enable = true;
    scanPath = "/srv/git";
    nginx.virtualHost = "git.cat4.org";
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
      clone-prefix = "https://git.cat4.org";
    };
  };
}