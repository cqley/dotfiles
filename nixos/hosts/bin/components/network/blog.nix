{ pkgs, ... }:
{
  network.services.blog = {
    site = "blog";
    data.blog = "/var/lib/blog";
  };

  systemd.services.blog = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/blog/.deno";
    environment.CWEBP = "${pkgs.libwebp}/bin/cwebp";
    script = ''
      exec ${pkgs.deno}/bin/deno run --no-prompt --allow-net=127.0.0.1:4600,127.0.0.1:4606 --allow-read=/var/lib/blog,${./sites/blog} --allow-write=/var/lib/blog --allow-run=${pkgs.libwebp}/bin/cwebp --allow-env=STATE_DIRECTORY,PORT,ADMIN_PORT,CWEBP ${./sites/blog}/server.js
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "blog";
      WorkingDirectory = "/var/lib/blog";
      Restart = "on-failure";
    };
  };

  services.nginx.virtualHosts."blog.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://127.0.0.1:4600";
  };

  services.nginx.virtualHosts."blog" = {
    extraConfig = "client_max_body_size 210m;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://127.0.0.1:4606";
  };
}
