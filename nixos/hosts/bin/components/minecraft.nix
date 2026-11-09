{ lib, pkgs, ... }:

let
  root = "/var/lib/minecraft";
  portFrom = 25565;
  portTo = 25580;

  javas = {
    "8" = pkgs.jdk8_headless;
    "17" = pkgs.jdk17_headless;
    "21" = pkgs.jdk21_headless;
    "25" = pkgs.jdk25_headless;
  };

  vanilla = pkgs.fetchurl {
    url = "https://piston-data.mojang.com/v1/objects/33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c/server.jar";
    name = "minecraft-server-26.3.jar";
    sha1 = "33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c";
  };

  advancements = pkgs.runCommand "advancements.json" { nativeBuildInputs = [ pkgs.unzip pkgs.jq ]; } ''
    unzip -q ${vanilla} 'META-INF/versions/*'
    unzip -q META-INF/versions/*/*.jar 'data/minecraft/advancement/*' assets/minecraft/lang/en_us.json
    cd data/minecraft/advancement
    find story nether end adventure husbandry -name '*.json' | sort | xargs jq -n --slurpfile lang ../../../assets/minecraft/lang/en_us.json '
      ["story", "nether", "end", "adventure", "husbandry"] as $cats
      | [inputs | select(.display) | { id: ("minecraft:" + (input_filename | rtrimstr(".json"))), parent, d: .display }]
      | (map({ key: .id, value: .parent }) | from_entries) as $up
      | def depth(i): if $up[i] then 1 + depth($up[i]) else 0 end;
      map({
        id,
        cat: (.id | ltrimstr("minecraft:") | split("/")[0]),
        title: ($lang[0][.d.title.translate] // .id),
        desc: ($lang[0][.d.description.translate] // ""),
        frame: (.d.frame // "task"),
        hidden: (.d.hidden // false),
        depth: depth(.id)
      })
      | sort_by([(.cat as $c | $cats | index($c)), .depth, .title])
      | map(del(.depth))
    ' > $out
  '';

  manifest = pkgs.writeText "manifest.json" (builtins.toJSON {
    name = "silly";
    short_name = "silly";
    start_url = "/dashboard";
    scope = "/";
    display = "standalone";
    background_color = "#161616";
    theme_color = "#161616";
    icons = map (n: { src = "/app/icon${toString n}.png"; sizes = "${toString n}x${toString n}"; type = "image/png"; }) [ 192 512 ];
  });

  app = pkgs.runCommand "silly" { nativeBuildInputs = [ pkgs.librsvg pkgs.gnused ]; } ''
    mkdir $out
    sed -e 's/#000000/#f2b8e2/' -e 's/stroke-opacity="0.9"//' -e 's/width="800px" height="800px" viewBox="0 0 400 400"/viewBox="-60 -60 520 520"/' ${./website/assets/cat.svg} > cat.svg
    for n in 180 192 512; do rsvg-convert -b '#161616' -w $n -h $n cat.svg -o $out/icon$n.png; done
    cp ${manifest} $out/manifest.json
  '';

  valid = ''
    valid() { [[ "$1" =~ ^[a-z0-9]{1,16}$ ]] && case "$1" in backups|dashboard|api|static|assets|app) false ;; esac; }
  '';

  sandbox = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    CapabilityBoundingSet = "";
  };

  start = pkgs.writeShellScript "minecraftstart" ''
    set -eu
    memory=$(${pkgs.jq}/bin/jq -r .memory server.json)
    [[ "$memory" =~ ^[0-9]{1,2}G$ ]] || { echo "bad memory: $memory"; exit 1; }
    case "$(${pkgs.jq}/bin/jq -r .java server.json)" in
    ${lib.concatStrings (lib.mapAttrsToList (v: j: "  ${v}) java=${j}/bin/java ;;\n") javas)}  *) echo "unknown java"; exit 1 ;;
    esac
    exec "$java" -Xms"$memory" -Xmx"$memory" -jar server.jar nogui
  '';

  stop = pkgs.writeShellScript "minecraftstop" ''
    echo stop > /run/minecraft/$1.stdin
    while ${pkgs.coreutils}/bin/kill -0 "$MAINPID" 2>/dev/null; do ${pkgs.coreutils}/bin/sleep 1; done
  '';

  server = {
    requires = [ "minecraft@%i.socket" ];
    after = [ "network.target" "minecraft@%i.socket" ];
    path = [ pkgs.gnused pkgs.jq ];
    environment.NAME = "%i";
    preStart = ''
      port=$(jq -r .port server.json)
      if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt ${toString portFrom} ] || [ "$port" -gt ${toString portTo} ]; then
        echo "bad port: $port"
        exit 1
      fi
      echo eula=true > eula.txt
      if [ -e server.properties ]; then
        sed -i "s/^server-port=.*/server-port=$port/" server.properties
        grep -q '^server-port=' server.properties || echo "server-port=$port" >> server.properties
      else
        printf 'server-port=%s\nmotd=%s\n' "$port" "$NAME" > server.properties
      fi
      for f in server.properties server.json; do [ ! -O "$f" ] || chmod g+rw "$f"; done
      mkdir -p mods
      chmod g+rwx mods
      level=$(sed -n 's/^level-name=//p' server.properties)
      level=''${level:-world}
      mkdir -p "$level/datapacks"
      chmod g+rwx "$level" "$level/datapacks"
    '';
    serviceConfig = sandbox // {
      ExecStart = "${start}";
      ExecStop = "${stop} %i";
      SuccessExitStatus = "0 143";
      User = "minecraft";
      Group = "minecraft";
      StateDirectory = "minecraft/%i";
      StateDirectoryMode = "0770";
      UMask = "0007";
      WorkingDirectory = "${root}/%i";
      StandardInput = "socket";
      StandardOutput = "journal";
      StandardError = "journal";
      Restart = "on-failure";
      TimeoutStopSec = 90;
    };
  };

  backup = {
    path = [ pkgs.coreutils pkgs.gnutar pkgs.gzip pkgs.pigz pkgs.gnused pkgs.systemd ];
    scriptArgs = "%i";
    script = valid + ''
      set -eu
      name=$1
      valid "$name"
      dir=${root}/backups/$name
      fifo=/run/minecraft/$name.stdin
      mkdir -p "$dir"
      cd ${root}/$name
      level=$(sed -n 's/^level-name=//p' server.properties 2>/dev/null || true)
      level=''${level:-world}
      if [ ! -d "$level" ]; then
        echo "no world yet"
        exit 1
      fi
      running=0
      resume() { if [ "$running" = 1 ]; then echo save-on > "$fifo"; fi; }
      trap resume EXIT
      if systemctl is-active --quiet "minecraft@$name.service"; then
        running=1
        echo save-off > "$fifo"
        echo "save-all flush" > "$fifo"
        sleep 5
      fi
      file="$dir/$(date +%Y%m%d%H%M%S).tar.gz"
      tar -I pigz --warning=no-file-changed -cf "$file.part" "$level" || [ $? -eq 1 ]
      mv "$file.part" "$file"
      ls -1t "$dir"/*.tar.gz | tail -n +8 | xargs -r rm -f
      echo "saved $file"
    '';
    serviceConfig = sandbox // {
      Type = "oneshot";
      User = "minecraft";
      Group = "minecraft";
      StateDirectory = "minecraft/backups";
      StateDirectoryMode = "0750";
      UMask = "0027";
    };
  };

  countdown = {
    path = [ pkgs.coreutils pkgs.systemd ];
    scriptArgs = "%i";
    script = valid + ''
      name=$1
      valid "$name" || exit 1
      unit=minecraft@$name.service
      say() { if systemctl is-active --quiet "$unit"; then echo "say $1" > /run/minecraft/$name.stdin; fi; }
      systemctl is-active --quiet "$unit" || exit 0
      say "server restarts in 5 minutes"
      sleep 240
      say "server restarts in 1 minute"
      sleep 50
      say "server restarts in 10 seconds"
      sleep 10
      systemctl restart "$unit"
    '';
    serviceConfig.Type = "oneshot";
  };

  restore = {
    path = [ pkgs.coreutils pkgs.gnutar pkgs.gzip pkgs.gnused pkgs.systemd ];
    scriptArgs = "%i";
    script = valid + ''
      set -eu
      name=''${1%%:*}
      file=''${1#*:}
      valid "$name"
      [[ "$file" =~ ^[0-9]+\.tar\.gz$ ]]
      src=${root}/backups/$name/$file
      [ -f "$src" ]
      unit=minecraft@$name.service
      was=0
      if systemctl is-active --quiet "$unit"; then was=1; fi
      systemctl stop "$unit"
      cd ${root}/$name
      level=$(sed -n 's/^level-name=//p' server.properties 2>/dev/null || true)
      level=''${level:-world}
      tmp=$(mktemp -d ${root}/$name/.restoreXXXXXX)
      tar -xzf "$src" -C "$tmp" --no-same-owner
      if [ ! -d "$tmp/$level" ]; then
        rm -rf "$tmp"
        echo "backup has no $level folder"
        exit 1
      fi
      rm -rf "''${level}previous"
      if [ -d "$level" ]; then mv "$level" "''${level}previous"; fi
      mv "$tmp/$level" "$level"
      rm -rf "$tmp"
      chown -R minecraft:minecraft "$level"
      chmod -R g+rwX "$level"
      echo "restored $file"
      if [ "$was" = 1 ]; then systemctl start "$unit"; fi
    '';
    serviceConfig.Type = "oneshot";
  };

  world = {
    path = [ pkgs.coreutils pkgs.gnutar pkgs.gzip pkgs.gnused pkgs.systemd pkgs.unzip pkgs.util-linux pkgs.findutils ];
    scriptArgs = "%i";
    script = valid + ''
      set -eu
      name=''${1%%:*}
      action=''${1#*:}
      valid "$name"
      case "$action" in reset|nether|end|import|delete) ;; *) echo "unknown action"; exit 1 ;; esac
      unit=minecraft@$name.service
      dir=${root}/$name
      staged=$dir/.import
      cd "$dir"
      level=$(sed -n 's/^level-name=//p' server.properties 2>/dev/null || true)
      level=''${level:-world}
      as() { setpriv --reuid=minecraft --regid=minecraft --init-groups -- "$@"; }
      was=0
      tmp=""
      finish() {
        if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
        if [ "$action" = import ]; then rm -f "$staged"; fi
        if [ "$was" = 1 ]; then systemctl start "$unit" || true; fi
      }
      trap finish EXIT
      if [ "$action" = import ] && [ ! -f "$staged" ]; then echo "nothing uploaded"; exit 1; fi
      if systemctl is-active --quiet "$unit"; then was=1; fi
      if [ -d "$level" ]; then systemctl start "minecraft-backup@$name.service"; fi
      systemctl stop "$unit"
      if [ "$action" = reset ] || [ "$action" = import ]; then
        for s in "$level/players/stats" "$level/stats"; do
          if [ -d "$s" ] && [ -n "$(ls -A "$s")" ]; then
            keep="$dir/.stats/$(date +%Y%m%d%H%M%S)"
            as mkdir -p "$keep"
            as cp -r "$s/." "$keep/"
            break
          fi
        done
      fi
      case "$action" in
        nether) as rm -rf "$level/DIM-1" "$level/dimensions/minecraft/the_nether" ;;
        end) as rm -rf "$level/DIM1" "$level/dimensions/minecraft/the_end" ;;
        reset) as rm -rf "$level" ;;
        delete)
          was=0
          cd /
          rm -rf "$dir"
          echo "deleted $name"
          exit 0
          ;;
        import)
          tmp=$(as mktemp -d "$dir/.worldXXXXXX")
          case "$(head -c 2 "$staged" | od -An -tx1 | tr -d ' \n')" in
            1f8b) as tar -xzf "$staged" -C "$tmp" --no-same-owner --no-same-permissions ;;
            504b) as unzip -q "$staged" -d "$tmp" ;;
            *) echo "not a zip or tar.gz file"; exit 1 ;;
          esac
          as find "$tmp" -type l -delete
          found=$(find "$tmp" -maxdepth 4 -name level.dat -type f -print -quit)
          if [ -z "$found" ]; then echo "no level.dat in the upload"; exit 1; fi
          as rm -rf "$level"
          as mv "$(dirname "$found")" "$level"
          ;;
      esac
      if [ -d "$level" ]; then as chmod -R g+rwX "$level"; fi
      echo "done: $action"
    '';
    serviceConfig.Type = "oneshot";
  };

  page = ./minecraft/page;
  site = ./minecraft/public;

  each = ''
    for cfg in ${root}/*/server.json; do
      [ -f "$cfg" ] || continue
      dir=''${cfg%/server.json}
      name=''${dir##*/}
      valid "$name" || continue
  '';
in
{
  users.users.minecraft = {
    isSystemUser = true;
    group = "minecraft";
    home = root;
  };
  users.groups.minecraft = { };

  users.users.mcpanel = {
    isSystemUser = true;
    group = "mcpanel";
    extraGroups = [ "minecraft" "systemd-journal" ];
  };
  users.groups.mcpanel = { };

  systemd.tmpfiles.rules = [
    "d ${root} 2770 minecraft minecraft -"
    "d /run/minecraft 0750 minecraft minecraft -"
  ];

  systemd.sockets."minecraft@" = {
    bindsTo = [ "minecraft@%i.service" ];
    socketConfig = {
      ListenFIFO = "/run/minecraft/%i.stdin";
      SocketMode = "0660";
      SocketUser = "minecraft";
      SocketGroup = "minecraft";
      RemoveOnStop = true;
      FlushPending = true;
    };
  };

  systemd.timers.minecraft-cron = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "minutely";
  };

  systemd.services = {
    "minecraft@" = server;
    "minecraft-backup@" = backup;
    "minecraft-restart@" = countdown;
    "minecraft-restore@" = restore;
    "minecraft-world@" = world;

    minecraft-cron = {
      path = [ pkgs.coreutils pkgs.systemd pkgs.jq pkgs.util-linux pkgs.findutils ];
      script = valid + ''
        now=$(date +%H:%M)
      '' + each + ''
          if [ "$(jq -r '.backup // empty' "$cfg")" = "$now" ]; then systemctl start --no-block "minecraft-backup@$name.service"; fi
          if [ "$(jq -r '.restart // empty' "$cfg")" = "$now" ]; then systemctl start --no-block "minecraft-restart@$name.service"; fi
          setpriv --reuid=minecraft --regid=minecraft --init-groups -- find "$dir" -mindepth 2 -maxdepth 2 -type f \( -name level.dat -o -name level.dat_old \) ! -perm -g=r -exec chmod g+r {} + 2>/dev/null || true
        done
      '';
      serviceConfig.Type = "oneshot";
    };

    minecraft-autostart = {
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
      path = [ pkgs.coreutils pkgs.systemd pkgs.jq ];
      script = valid + each + ''
          if [ "$(jq -r '.autostart // false' "$cfg")" = true ]; then systemctl start --no-block "minecraft@$name.service"; fi
        done
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    mcpanel = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "systemd-tmpfiles-setup.service" ];
      path = [ pkgs.systemd ];
      environment.DENO_DIR = "/var/lib/mcpanel/.deno";
      script = ''
        exec ${pkgs.deno}/bin/deno run --no-prompt --allow-net=127.0.0.1,api.modrinth.com,cdn.modrinth.com,piston-meta.mojang.com,piston-data.mojang.com,meta.fabricmc.net,sessionserver.mojang.com --allow-read=${root},/var/lib/mcpanel,/run/minecraft,${page},${site},${advancements} --allow-write=${root},/var/lib/mcpanel,/run/minecraft --allow-run=systemctl,journalctl ${./minecraft/panel.js} ${page} ${site} ${advancements}
      '';
      serviceConfig = {
        User = "mcpanel";
        Group = "mcpanel";
        StateDirectory = "mcpanel";
        WorkingDirectory = "/var/lib/mcpanel";
        ReadWritePaths = [ root ];
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "mcpanel" &&
          /^minecraft(-backup|-restart|-restore|-world)?@/.test(action.lookup("unit")) &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  networking.firewall.allowedTCPPortRanges = [{ from = portFrom; to = portTo; }];

  services.nginx.virtualHosts."1f2t.org".locations."/packs/" = {
    alias = "/var/lib/mcpanel/packs/";
    extraConfig = ''
      default_type application/zip;
      add_header Cache-Control "public, max-age=31536000, immutable" always;
      add_header Strict-Transport-Security "max-age=31536000" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Referrer-Policy "same-origin" always;
    '';
  };

  services.nginx.virtualHosts."silly" = {
    listen = [{ addr = "10.0.0.1"; port = 8090; }];
    extraConfig = "client_max_body_size 4g;";
    locations."/assets/".alias = "/etc/assets/";
    locations."/app/".alias = "${app}/";
    locations."/static/".alias = "${page}/";
    locations."/" = {
      proxyPass = "http://127.0.0.1:4603";
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 1d;
      '';
    };
  };

  services.nginx.virtualHosts."mc.1f2t.org" = {
    forceSSL = true;
    enableACME = true;
    locations."/assets/".alias = "/etc/assets/";
    locations."/static/".alias = "${site}/";
    locations."/".proxyPass = "http://127.0.0.1:4604";
  };
}
