{ ... }:
{
  services.cgit."1f2t" = {
    enable = true;
    scanPath = "/srv/git";
    nginx.virtualHost = "git.1f2t.org";
    gitHttpBackend = {
      enable = true;
      checkExportOkFiles = false;
    };
    settings = {
      root-title = "1f2t";
      root-desc = "git repositories";
      logo = "";
      favicon = "/assets/cat.svg";
      css = "/assets/cgit.css";

      enable-index-owner = 0;
      enable-commit-graph = 1;
      enable-log-filecount = 1;
      enable-log-linecount = 1;
      enable-follow-links = 1;
      enable-http-clone = 1;

      readme = ":README.md";
      snapshots = "tar.gz zip";
      max-stats = "year";
      clone-prefix = "https://git.1f2t.org";
    };
  };

  services.nginx.virtualHosts."git.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/assets/".alias = "/etc/website-assets/";
  };
}
