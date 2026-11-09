{ pkgs, ... }:
{
  systemd.services.blog = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/blog/.deno";
    script = ''
      exec ${pkgs.deno}/bin/deno run --no-prompt --allow-net=127.0.0.1:4600 --allow-read=/var/lib/blog,${./sites/blog} --allow-write=/var/lib/blog --allow-env=STATE_DIRECTORY,PORT ${./sites/blog}/server.js
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
    extraConfig = "client_max_body_size 20m;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/".proxyPass = "http://127.0.0.1:4600";
  };
}
