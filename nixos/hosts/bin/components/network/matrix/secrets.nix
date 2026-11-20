{ bin, ... }:

let
  dir = "/var/lib/matrixsecrets";
  needs = {
    requires = [ "matrixsecrets.service" ];
    after = [ "matrixsecrets.service" ];
  };
in
{
  network.services = {
    tuwunel = {
      link = "https://federationtester.matrix.org/#matrix.1f2t.org";
      data.matrix = "/var/lib/tuwunel";
    };
    livekit = { };
    lk-jwt-service = { };
    coturn = { };
  };

  systemd.services.matrixsecrets = bin.secret "matrixsecrets" ''
    [ -s registration ] || gen 32 > registration
    [ -s turn ] || gen 32 > turn
    [ -s livekit ] || printf 'tuwunel: %s\n' "$(gen 32)" > livekit
  '';

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
