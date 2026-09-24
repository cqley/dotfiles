{ ... }:

{
  environment.etc."website".source = ./website;

  services.nginx.virtualHosts."1f2t.org" = {
    forceSSL = true;
    enableACME = true;

    root = "/etc/website";

    extraConfig = ''
      error_page 404 /404.html;
    '';

    locations = {
      "= /blog" = {
        return = "301 https://blog.1f2t.org/";
      };

      "= /blog/" = {
        return = "301 https://blog.1f2t.org/";
      };

      "= /contact" = {
        tryFiles = "/contact.html =404";
      };

      "= /skills" = {
        tryFiles = "/skills.html =404";
      };

      "/" = {
        tryFiles = "$uri $uri/ =404";
      };
    };
  };
}