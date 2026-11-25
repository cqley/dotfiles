{ config, lib, pkgs, bin, ... }:

let
  downloader = bin.go "downloader" ./downloader;
  beets = pkgs.writeText "beets.yaml" (builtins.toJSON {
    directory = "/var/lib/navidrome/music";
    library = "/var/lib/navidrome/.beets/library.db";
    plugins = "musicbrainz lyrics replaygain";
    ui.color = false;
    import = { move = true; quiet_fallback = "asis"; };
    paths.singleton = "\$artist/\$title";
    lyrics = { auto = true; sources = "lrclib"; synced = true; };
    replaygain = { auto = true; backend = "ffmpeg"; };
  });
  beet = pkgs.writeShellScriptBin "beet" ''
    export BEETSDIR=/var/lib/navidrome/.beets PATH=${pkgs.ffmpeg}/bin:$PATH
    exec ${pkgs.beets}/bin/beet -c ${beets} "$@"
  '';
  tag = pkgs.writeShellScriptBin "tag" ''
    ${beet}/bin/beet import -q -s "$1"
    ${beet}/bin/beet write
    ${pkgs.findutils}/bin/find "$1" -type f -name '*.mp3' -exec ${pkgs.coreutils}/bin/mv -n -t /var/lib/navidrome/music {} +
    ${pkgs.coreutils}/bin/rm -rf "$1"
  '';
  tidy = [ "--parse-metadata" "title:(?P<artist>.+?) [-–—] (?P<title>.+)" "--replace-in-metadata" "title" ''(?i)\s*[(\[][^)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|hd|4k|mv)[^)\]]*[)\]]|\s+(ft|feat)\.?\s.*'' "" ];
  podcasts = {
    edeltalk = { list = "PL_PrOB576HxI0mXdEVlBRpB2zerTAGCss"; newest = "1:3"; };
    unfassbar = { list = "PLEjgu53NfIVDFSb4HV3Qj7-IF4TQlXBNp"; newest = "1:3"; };
    henkescorner = { list = "PLnEam709xEo1DuqpEFBR43gEYBFfQyM7D"; newest = "-3:"; };
    wanshow = { list = "PLBKxjEPgnXa0"; newest = "1:3"; };
  };
  sandbox = bin.sandbox // {
    ReadWritePaths = [ "/var/lib/navidrome" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
  };
in
{
  network.services = lib.mapAttrs (name: podcast: {
    units = [ "${name}.timer" ];
    link = "https://www.youtube.com/playlist?list=${podcast.list}";
  }) podcasts // {
    navidrome = {
      link = "https://music.1f2t.org/";
      data.music = "/var/lib/navidrome";
    };
    downloader = {
      units = [ "downloader.service" "downloader.socket" ];
      site = "downloader";
    };
  };

  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/var/lib/navidrome/music";
      Scanner.PurgeMissing = "full";
    };
  };

  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.deno
    pkgs.spotdl
    beet
    (pkgs.writeShellScriptBin "music" ''
      [[ $# -lt 2 ]] && { echo "usage: music [song|playlist] url"; exit 1; }
      doas -u navidrome mkdir -p /var/lib/navidrome/tmp
      d=$(doas -u navidrome mktemp -d /var/lib/navidrome/tmp/XXXXXX) || exit 1
      if [[ "$2" == *"spotify.com"* ]]; then
        doas -u navidrome env HOME=/var/lib/navidrome XDG_CONFIG_HOME=/var/lib/navidrome/.config ${pkgs.spotdl}/bin/spotdl download "$2" --output "$d" --format mp3
      else
        args=(-x --audio-format mp3 --embed-metadata --embed-thumbnail ${lib.escapeShellArgs tidy} -o '%(title)s.%(ext)s' -P "$d")
        [[ $1 == "song" ]] && args+=(--no-playlist)
        doas -u navidrome ${pkgs.yt-dlp}/bin/yt-dlp "''${args[@]}" "$2"
      fi
      doas -u navidrome ${tag}/bin/tag "$d"
    '')
  ];

  systemd.services = lib.mapAttrs (name: podcast: {
    script = ''
      mkdir -p /var/lib/navidrome/.podcasts
      if ! out=$(${pkgs.yt-dlp}/bin/yt-dlp -i -x --audio-format mp3 --embed-metadata --embed-thumbnail \
        --playlist-items ${podcast.newest} \
        --download-archive /var/lib/navidrome/.podcasts/${name} \
        -o "%(title)s.%(ext)s" \
        -P /var/lib/navidrome/music \
        "https://www.youtube.com/playlist?list=${podcast.list}" 2>&1); then
        printf '%s\n' "$out"
        if printf '%s\n' "$out" | grep '^ERROR' | grep -qv 'Private video'; then exit 1; fi
        exit 0
      fi
      printf '%s\n' "$out"
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
      requires = [ "downloader.socket" ];
      after = [ "downloader.socket" ];
      path = [ pkgs.yt-dlp pkgs.ffmpeg pkgs.deno pkgs.spotdl pkgs.zip tag ];
      environment = {
        HOME = "/var/lib/navidrome";
        XDG_CONFIG_HOME = "/var/lib/navidrome/.config";
        XDG_CACHE_HOME = "/var/lib/navidrome/.cache";
        DENO_DIR = "/var/lib/navidrome/.deno";
        DOWNLOADER_ORIGINS = config.network.origins.downloader;
      };
      serviceConfig = sandbox // {
        ExecStart = "${downloader}/bin/downloader";
        User = "navidrome";
        WorkingDirectory = "/var/lib/navidrome";
        Restart = "on-failure";
      };
    };
  };

  systemd.sockets.downloader = bin.socket [ "/run/downloader.sock" ];

  services.nginx.virtualHosts."music.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.0.1:4533";
    locations."/assets/".alias = "/etc/assets/";
  };

  services.nginx.virtualHosts."downloader" = {
    locations."/assets/".alias = "/etc/assets/";
    locations."/" = {
      proxyPass = "http://unix:/run/downloader.sock";
      extraConfig = ''
        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
        proxy_buffering off;
      '';
    };
  };
}
