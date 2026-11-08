{ ... }:

{
  services.matrix-tuwunel = {
    enable = true;

    settings.global = {
      server_name = "matrix.1f2t.org";
      allow_registration = true;
      registration_token = "YWvscPJI3dkE6PLkwRvNZ2wPyhxvUUJl";
      allow_federation = true;
      allow_encryption = true;

      turn_uris = [
        "turn:matrix.1f2t.org:3478?transport=udp"
        "turn:matrix.1f2t.org:3478?transport=tcp"
        "turns:matrix.1f2t.org:5349?transport=tcp"
      ];
      turn_secret = "4626905729e91d52d10c68a9e31499c8f595270d87c9b898a187c0d98080f3ef";
      turn_ttl = 86400;

      well_known = {
        client = "https://matrix.1f2t.org";
        server = "matrix.1f2t.org:443";
        livekit_url = "https://livekit.1f2t.org";
      };
    };
  };
}