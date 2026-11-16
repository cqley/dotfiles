{
  networking.hosts = {
    "10.0.0.1" = [ "bin" ];
    "10.0.0.2" = [ "box" ];
    "10.0.0.3" = [ "bed" ];
    "10.0.0.4" = [ "phone" ];
  };

  programs.ssh.knownHosts.bin = {
    hostNames = [ "bin" "10.0.0.1" "5.231.118.153" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMj59OaH5wP7xicn35YobPLaB7hpnvlkrAVlcMi5a08";
  };
}
