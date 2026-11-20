{ ... }:
{
  environment.etc."website".source = ./sites/website;

  services.nginx.virtualHosts."1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    root = "/etc/website";
    extraConfig = "error_page 404 /404.html;";
    locations = {
      "/assets/".alias = "/etc/assets/";
      "= /blog".return = "301 https://blog.1f2t.org/";
      "= /blog/".return = "301 https://blog.1f2t.org/";
      "= /contact".return = "301 /";
      "= /skills".return = "301 /";
      "/".tryFiles = "$uri $uri/ =404";
    };
  };
}
