{ ... }:

{
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [ "10.0.0.0/24" ];
    bantime-increment.enable = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = 0;
    "net.ipv4.conf.default.forwarding" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "dev.tty.ldisc_autoload" = 0;
    "kernel.kexec_load_disabled" = 1;
  };

  services.openssh = {
    authorizedKeysInHomedir = false;
    settings.AllowUsers = [ "cat" "git" ];
  };
}
