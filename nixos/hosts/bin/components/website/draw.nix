{ lib, pkgs, ... }:

let
  title = "画";

  image = pkgs.dockerTools.pullImage {
    imageName = "excalidraw/excalidraw";
    imageDigest = "sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9";
    finalImageTag = "latest";
    os = "linux";
    arch = "amd64";
    hash = "sha256-TKtRRG0Yqq5L4i6TKfusI2YNN6TVieigkLcCjSnQ2aM=";
  };

  assistantFonts = lib.mapAttrsToList (weight: hash: pkgs.fetchurl {
    name = "Assistant-${weight}.woff2";
    url = "https://excalidraw.nyc3.cdn.digitaloceanspaces.com/oss/fonts/Assistant/Assistant-${weight}.woff2";
    inherit hash;
  }) {
    Regular = "sha256-dpRfCSJarmW9vSBMtKxA1Mqk/2cVDlB0urGgTRt3j8M=";
    Medium = "sha256-ganygM5qeQ8gyozVIRg8qkMPH3/cB1LDbvHMbcgorFc=";
    SemiBold = "sha256-u6R6fRsYWkouDSZeyCrqxdvC3Jyw9IKi/1fL3+TlBF0=";
    Bold = "sha256-4M3TMs4Dl3DpPsRDNrbbZfkxlA9CsDQqrTWgbn+ZHSk=";
  };

  draw = pkgs.runCommand "draw" { nativeBuildInputs = [ pkgs.jq pkgs.nodejs ]; } ''
    mkdir image root
    tar -xf ${image} -C image
    for layer in $(jq -r '.[0].Layers[]' image/manifest.json); do
      tar -xf "image/$layer" -C root usr/share/nginx/html 2>/dev/null || true
    done
    cp -r root/usr/share/nginx/html $out
    chmod -R u+w $out
    mkdir -p $out/fonts/Assistant
    ${lib.concatMapStringsSep "\n" (font: "cp ${font} $out/fonts/Assistant/${font.name}") assistantFonts}
    cp ${./assets/cat.svg} $out/favicon.svg
    cp ${./sites/draw/sw.js} $out/sw.js
    cp ${./sites/draw/sw.js} $out/service-worker.js
    rm -f $out/favicon.ico $out/favicon-16x16.png $out/favicon-32x32.png $out/apple-touch-icon.png
    node ${./sites/draw/patch.mjs} $out ${./sites/draw/custom.css} ${lib.escapeShellArg title}
  '';
in
{
  systemd.services.draw = {
    wantedBy = [ "multi-user.target" ];
    environment.DENO_DIR = "/var/lib/draw/.deno";
    script = ''
      exec ${pkgs.deno}/bin/deno run --allow-net --allow-read --allow-write --allow-env ${./sites/draw/server.js}
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "draw";
      WorkingDirectory = "/var/lib/draw";
      Restart = "on-failure";
    };
  };

  services.nginx.virtualHosts."draw.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    root = draw;
    locations."/".tryFiles = "$uri $uri/ /index.html";
    locations."/api/v2/" = {
      proxyPass = "http://127.0.0.1:4602";
      extraConfig = "client_max_body_size 6m;";
    };
    locations."/assets/".extraConfig = ''
      expires 1y;
      add_header Cache-Control "public, immutable" always;
      add_header Strict-Transport-Security "max-age=31536000" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "same-origin" always;
    '';
  };
}
