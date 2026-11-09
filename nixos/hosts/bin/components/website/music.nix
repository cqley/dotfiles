{ lib, pkgs, ... }:

let
  podcasts = {
    edeltalk = { list = "PL_PrOB576HxI0mXdEVlBRpB2zerTAGCss"; newest = "1"; };
    unfassbar = { list = "PLEjgu53NfIVDFSb4HV3Qj7-IF4TQlXBNp"; newest = "1"; };
    henkescorner = { list = "PLnEam709xEo1DuqpEFBR43gEYBFfQyM7D"; newest = "-1"; };
    wanshow = { list = "PLBKxjEPgnXa0"; newest = "1"; };
  };
  sandbox = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [ "/var/lib/navidrome" ];
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    CapabilityBoundingSet = "";
  };
in
{
  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/var/lib/navidrome/music";
    };
  };

  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.deno
    pkgs.spotdl
    (pkgs.writeShellScriptBin "music" ''
      [[ $# -lt 2 ]] && { echo "usage: music [song|playlist] url"; exit 1; }
      if [[ "$2" == *"spotify.com"* ]]; then
        exec doas -u navidrome env HOME=/var/lib/navidrome XDG_CONFIG_HOME=/var/lib/navidrome/.config ${pkgs.spotdl}/bin/spotdl download "$2" --output /var/lib/navidrome/music --format mp3
      else
        args=(-x --audio-format mp3 --embed-metadata --embed-thumbnail -o '%(title)s.%(ext)s' -P /var/lib/navidrome/music)
        [[ $1 == "song" ]] && args+=(--no-playlist)
        exec doas -u navidrome ${pkgs.yt-dlp}/bin/yt-dlp "''${args[@]}" "$2"
      fi
    '')
  ];

  systemd.services = lib.mapAttrs (name: podcast: {
    script = ''
      mkdir -p /var/lib/navidrome/.podcasts
      ${pkgs.yt-dlp}/bin/yt-dlp -x --audio-format mp3 --embed-metadata --embed-thumbnail \
        --playlist-items ${podcast.newest} \
        --download-archive /var/lib/navidrome/.podcasts/${name} \
        -o "%(title)s.%(ext)s" \
        -P /var/lib/navidrome/music \
        "https://www.youtube.com/playlist?list=${podcast.list}"
    '';
    path = [ pkgs.ffmpeg pkgs.deno ];
    serviceConfig = sandbox // {
      Type = "oneshot";
      User = "navidrome";
    };
    startAt = "hourly";
  }) podcasts // {
    downloader = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.yt-dlp pkgs.ffmpeg pkgs.deno pkgs.spotdl pkgs.zip ];
      environment = {
        HOME = "/var/lib/navidrome";
        XDG_CONFIG_HOME = "/var/lib/navidrome/.config";
        XDG_CACHE_HOME = "/var/lib/navidrome/.cache";
        DENO_DIR = "/var/lib/navidrome/.deno";
      };
      script = ''
        exec ${pkgs.deno}/bin/deno run --no-prompt --allow-net=127.0.0.1:4534 --allow-run=yt-dlp,spotdl,zip --allow-read=/var/lib/navidrome --allow-write=/var/lib/navidrome ${./sites/downloader/server.js}
      '';
      serviceConfig = sandbox // {
        User = "navidrome";
        WorkingDirectory = "/var/lib/navidrome";
        Restart = "on-failure";
      };
    };
  };

  services.nginx.virtualHosts."music.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:4533";
    locations."/assets/".alias = "/etc/assets/";
    locations."= /downloader".return = "301 $scheme://$host/downloader/";
    locations."/downloader/" = {
      proxyPass = "http://127.0.0.1:4534/";
      extraConfig = ''
        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
        proxy_buffering off;
      '';
    };
  };
}
