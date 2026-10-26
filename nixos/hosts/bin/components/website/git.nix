{ ... }:
{
  services.forgejo = {
    enable = true;

    database.type = "sqlite3";

    settings = {
      server = {
        DOMAIN = "git.1f2t.org";
        ROOT_URL = "https://git.1f2t.org/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
        DISABLE_SSH = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
      session = {
        COOKIE_SECURE = true;
      };
      other = {
        SHOW_FOOTER_VERSION = false;
        SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
        SHOW_FOOTER_POWERED_BY = false;
      };
      DEFAULT = {
        APP_NAME = "Beyond coding. We Forge.";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/forgejo/custom/public 0750 forgejo forgejo - -"
    "d /var/lib/forgejo/custom/public/assets 0750 forgejo forgejo - -"
    "d /var/lib/forgejo/custom/public/assets/img 0750 forgejo forgejo - -"
    "d /var/lib/forgejo/custom/templates 0750 forgejo forgejo - -"
    "d /var/lib/forgejo/custom/templates/custom 0750 forgejo forgejo - -"
    "L+ /var/lib/forgejo/custom/public/assets/img/logo.svg - - - - ${./assets/home.svg}"
    "L+ /var/lib/forgejo/custom/public/assets/img/favicon.svg - - - - ${./assets/cat.svg}"
    "L+ /var/lib/forgejo/custom/templates/custom/header.tmpl - - - - ${./forgejo-header.tmpl}"
  ];

  services.nginx.virtualHosts."git.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:3000";
  };
}
