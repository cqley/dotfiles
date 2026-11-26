{
  services.openssh = {
    enable = true;
    openFirewall = false;
    authorizedKeysInHomedir = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "cat" ];
    };
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];

  programs.git = {
    enable = true;
    config.url."git@bin:".insteadOf = [ "git@git.1f2t.org:" "ssh://git@git.1f2t.org/" ];
  };

  users.users.cat.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJq3Lw3QReo6e9S1jbt1AywvaLKfgTY/GagPsfReP+t cat@box"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlgxVpCMZUQkhkpepEkJ4IoOz/EtnxSoh38qisHMGPn cat@bed"
  ];
}
