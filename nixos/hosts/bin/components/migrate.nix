{ ... }:

{
  system.activationScripts.renamestate = ''
    move() {
      if [ -e "$1" ] && [ ! -e "$2" ]; then
        mv "$1" "$2"
        echo "moved $1 to $2"
      fi
    }
    move /var/lib/private/linx-server /var/lib/private/linx
    move /var/lib/private/filehost-dashboard /var/lib/private/filehost
    move /var/lib/navidrome/.downloader-token /var/lib/navidrome/.downloadertoken
    for old in /var/lib/linx-server /var/lib/filehost-dashboard; do
      [ -L "$old" ] && rm "$old"
    done
    true
  '';
}
