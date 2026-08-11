{ pkgs, ... }: {
  systemd.tmpfiles.rules = [
    "d /var/lib/aria2 0755 cat users -"
    "d /home/cat/downloads 0755 cat users -"
  ];

  environment.etc."nixos/secrets/aria2" = {
    text = "cat";
    mode = "0400";
    user = "cat";
    group = "users";
  };

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

  environment.systemPackages = with pkgs; [
    ariang
  ];
}
