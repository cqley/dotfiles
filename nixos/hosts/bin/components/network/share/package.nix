{ stdenv, go }:

stdenv.mkDerivation {
  pname = "share";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ go ];
  buildPhase = ''
    export HOME=$TMPDIR GOCACHE=$TMPDIR/cache GOPATH=$TMPDIR/go GOTOOLCHAIN=local CGO_ENABLED=0
    go build -o share main.go
  '';
  installPhase = "install -Dm755 share $out/bin/share";
}
