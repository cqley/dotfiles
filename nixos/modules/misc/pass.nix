{ pkgs, ... }: {
  programs.password-store = {
    enable = true;
    package = pkgs.pass;
  };

  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-all;
  };
}