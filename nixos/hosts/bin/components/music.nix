{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 4533 ];

  services.navidrome = {
    enable = true;
    settings = {
      Address = "5.231.118.254";
      Port = 4533;
      MusicFolder = "/var/lib/navidrome/music";
    };
  };

  environment.systemPackages = [
    pkgs.ffmpeg
    (pkgs.writeShellScriptBin "music" ''
      [[ $# -lt 2 ]] && { echo "usage: music [song|playlist] url"; exit 1; }
      cd /var/lib/navidrome/music || exit 1
      args=(-x --audio-format mp3 --embed-metadata --embed-thumbnail -o '%(title)s.%(ext)s')
      [[ $1 == "song" ]] && args+=(--no-playlist)
      exec ${pkgs.yt-dlp}/bin/yt-dlp "''${args[@]}" "$2"
    '')
  ];

  systemd.services.edeltalk = {
    script = ''
      cd /var/lib/navidrome/music || exit 1
      yt-dlp -x --audio-format mp3 --embed-metadata --embed-thumbnail \
        --playlist-items 1 \
        -o "%(title)s.%(ext)s" \
        "https://music.youtube.com/playlist?list=PL_PrOB576HxI0mXdEVlBRpB2zerTAGCss"
    '';
    path = [ pkgs.yt-dlp pkgs.ffmpeg ];
    serviceConfig = {
      Type = "oneshot";
      User = "navidrome";
    };
    startAt = "*:0/3";
  };
}
