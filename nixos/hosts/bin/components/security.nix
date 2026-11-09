{ ... }:

{
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [ "10.0.0.0/24" ];
    bantime-increment.enable = true;
  };
}
