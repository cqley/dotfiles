{ lib, ... }:

let
  sites = {
    dash = 8081;
    immich = 2283;
    silly = 8090;
    notes = 8091;
    blog = 8092;
    share = 8093;
    downloader = 8094;
    aiostreams = 8095;
    jellyfin = 8096;
  };
in
{
  options.names.sites = lib.mkOption {
    readOnly = true;
    default = sites;
  };

  config = {
    networking.hosts = {
      "10.0.0.1" = [ "bin" ] ++ map (name: "${name}.bin") (lib.attrNames sites);
      "10.0.0.2" = [ "box" ];
      "10.0.0.3" = [ "bed" ];
      "10.0.0.4" = [ "phone" ];
    };

    programs.ssh.knownHosts.bin = {
      hostNames = [ "bin" "10.0.0.1" "5.231.118.153" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMj59OaH5wP7xicn35YobPLaB7hpnvlkrAVlcMi5a08";
    };
  };
}
