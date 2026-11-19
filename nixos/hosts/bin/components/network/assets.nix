{ pkgs, ... }:
{
  environment.etc."assets".source = pkgs.runCommand "assets" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    cp -r ${./assets} $out
    chmod u+w $out
    rsvg-convert -w 256 -h 256 $out/icon.svg -o $out/icon.png
    rsvg-convert -b '#161616' --page-width 512 --page-height 512 --left 96 --top 96 -w 320 -h 320 $out/icon.svg -o $out/touch.png
  '';
}
