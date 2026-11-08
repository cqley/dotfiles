{ ... }:

{
  imports = [
    ./matrix/homeserver.nix
    ./matrix/nginx.nix
    ./matrix/turn.nix
    ./matrix/livekit.nix
  ];
}