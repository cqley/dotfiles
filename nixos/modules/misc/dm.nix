{ pkgs, ... }: {
  services.aria2 = {
    enable = true;
    rpcSecretFile = "/etc/nixos/secrets/aria2";
    settings = {
      dir = "/home/cat/downloads";
      rpc-allow-origin-all = true;
      rpc-listen-all = false;
      enable-dht = true;
      bt-enable-lpd = true;
      enable-peer-exchange = true;
    };
  };

  systemd.services.aria2.serviceConfig = {
    User = pkgs.lib.mkForce "cat";
    Group = pkgs.lib.mkForce "users";
    ProtectHome = pkgs.lib.mkForce false;
    DynamicUser = pkgs.lib.mkForce false;
  };
}
