{ pkgs, ... }:

let
  dir = "/var/lib/matrixsecrets";
  needs = {
    requires = [ "matrixsecrets.service" ];
    after = [ "matrixsecrets.service" ];
  };
in
{
  systemd.services.matrixsecrets = {
    path = [ pkgs.coreutils ];
    script = ''
      umask 077
      gen() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
      [ -s ${dir}/registration ] || gen > ${dir}/registration
      [ -s ${dir}/turn ] || gen > ${dir}/turn
      [ -s ${dir}/livekit ] || printf 'tuwunel: %s\n' "$(gen)" > ${dir}/livekit
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "matrixsecrets";
      StateDirectoryMode = "0700";
    };
  };

  systemd.services.tuwunel = needs // {
    serviceConfig.LoadCredential = [
      "registration:${dir}/registration"
      "turn:${dir}/turn"
    ];
  };

  systemd.services.coturn = needs // {
    serviceConfig.LoadCredential = [ "turn:${dir}/turn" ];
  };

  systemd.services.livekit = needs;
  systemd.services.lk-jwt-service = needs;
}
