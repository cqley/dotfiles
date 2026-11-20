{ pkgs, ... }:

let
  assets = pkgs.runCommand "assets" { nativeBuildInputs = [ pkgs.woff2 ]; } ''
    cp -r ${./assets} $out
    chmod u+w $out
    mkdir $out/fonts
    for f in ${pkgs.libertinus}/share/fonts/truetype/LibertinusSerif-{Regular,Italic,Bold,BoldItalic}.ttf ${pkgs.courier-prime}/share/fonts/truetype/CourierPrime-*.ttf; do
      cp $f $out/fonts/
    done
    chmod u+w $out/fonts/*
    for f in $out/fonts/*.ttf; do
      woff2_compress $f
      rm $f
    done
  '';
in
{
  environment.etc."assets".source = assets;
}
