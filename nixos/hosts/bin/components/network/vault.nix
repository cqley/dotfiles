{ ... }:

{
  network.services.vaultwarden = {
    site = "vault";
    data.vault = "/var/lib/vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://vault.bin";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      IP_HEADER = "X-Real-IP";
      SIGNUPS_ALLOWED = true;
      INVITATIONS_ALLOWED = false;
      ORG_CREATION_USERS = "none";
      SENDS_ALLOWED = false;
      EMERGENCY_ACCESS_ALLOWED = false;
      PASSWORD_HINTS_ALLOWED = false;
      SHOW_PASSWORD_HINT = false;
      DISABLE_ICON_DOWNLOAD = true;
      ICON_SERVICE = "internal";
      PUSH_ENABLED = false;
    };
  };

  systemd.services.vaultwarden.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = "localhost";
    NoExecPaths = [ "/" ];
    ExecPaths = [ "/nix/store" ];
    MemoryMax = "512M";
  };

  services.nginx.virtualHosts."vault" = {
    extraConfig = "client_max_body_size 25m;";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8222";
      proxyWebsockets = true;
    };
  };
}
