{ pkgs, ... }:
{
  systemd.services.blog-web = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/blog/.deno";
    script = ''
      exec ${pkgs.deno}/bin/deno run --allow-net --allow-read --allow-write --allow-env ${./blog/server.js}
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "blog";
      WorkingDirectory = "/var/lib/blog";
    };
  };

  services.nginx.virtualHosts."blog.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:4600";
  };
}
