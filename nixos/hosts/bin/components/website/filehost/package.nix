{ stdenv, go }:

stdenv.mkDerivation {
  pname = "filehost";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ go ];
  buildPhase = ''
    export HOME=$TMPDIR GOCACHE=$TMPDIR/cache GOPATH=$TMPDIR/go GOTOOLCHAIN=local CGO_ENABLED=0
    go build -o filehost main.go
  '';
  installPhase = "install -Dm755 filehost $out/bin/filehost";
}
