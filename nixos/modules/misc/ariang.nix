{ pkgs, ... }: {
  systemd.tmpfiles.rules = [
    "d /var/lib/aria2 0755 cat users -"
    "d /home/cat/downloads 0755 cat users -"
  ];

  services.aria2 = {
    enable = true;
    rpcSecretFile = "/var/lib/aria2/secret";
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

  environment.systemPackages = with pkgs; [
    ariang
  ];
}
