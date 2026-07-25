{
  networking.firewall.allowedTCPPorts = [ 4533 ];
  
  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/var/lib/navidrome/music";
    };
  };
}
