{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  sites = config.names.sites;
  vhosts = config.services.nginx.virtualHosts;
  port = name: toString sites.${name};
  certs = "/var/lib/bincert";
  san = lib.concatMapStringsSep "," (name: "DNS:${name}.bin") (lib.attrNames sites);
in
{
  options.network = {
    services = mkOption {
      default = { };
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          units = mkOption {
            type = types.listOf types.str;
            default = [ "${name}.service" ];
          };
          data = mkOption {
            type = types.attrsOf types.str;
            default = { };
          };
          site = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          link = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      }));
    };

    origins = mkOption {
      readOnly = true;
      default = lib.mapAttrs (name: _: "http://10.0.0.1:${port name} http://bin:${port name} http://${name}.bin https://${name}.bin") sites;
    };
  };

  config = {
    _module.args.bin = {
      sandbox = {
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };

      outside = [ "localhost" "link-local" "multicast" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10" "fc00::/7" "5.231.118.153" "2a14:7c0:1002:1307::/64" ];

      socket = streams: {
        wantedBy = [ "sockets.target" ];
        listenStreams = streams;
        socketConfig = {
          SocketUser = "nginx";
          SocketGroup = "nginx";
          SocketMode = "0600";
        };
      };

      secret = name: body: {
        path = [ pkgs.coreutils ];
        script = ''
          umask 077
          cd /var/lib/${name}
          gen() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
          ${body}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = name;
          StateDirectoryMode = "0700";
        };
      };

      go = name: src: pkgs.stdenv.mkDerivation {
        pname = name;
        version = "0.1.0";
        inherit src;
        nativeBuildInputs = [ pkgs.go ];
        buildPhase = ''
          export HOME=$TMPDIR GOCACHE=$TMPDIR/cache GOPATH=$TMPDIR/go GOTOOLCHAIN=local CGO_ENABLED=0
          go build -o ${name} main.go
        '';
        installPhase = "install -Dm755 ${name} $out/bin/${name}";
      };
    };

    network.services = {
      nginx.link = "https://1f2t.org/";
      sshd = { };
      fail2ban = { };
      wireguard.units = [ "wireguard-wg0.service" ];
      dnsmasq = { };
      syncthing.data.public = "/home/cat/public";
      git = {
        units = [ "fcgiwrap-git.socket" "gittrash.timer" ];
        link = "https://git.1f2t.org/";
        data.git = "/var/lib/git";
      };
    };

    services.nginx.virtualHosts = lib.mapAttrs (name: _: {
      serverName = "10.0.0.1";
      serverAliases = [ "bin" ];
      listen = [{ addr = "10.0.0.1"; port = sites.${name}; }];
    }) sites // lib.mapAttrs' (name: _: lib.nameValuePair "${name}.bin" {
      listen = [ { addr = "10.0.0.1"; port = 80; } { addr = "10.0.0.1"; port = 443; ssl = true; } ];
      forceSSL = true;
      sslCertificate = "${certs}/bin.crt";
      sslCertificateKey = "${certs}/bin.key";
      inherit (vhosts.${name}) root extraConfig locations;
    }) sites // {
      private = {
        default = true;
        listen = map (port: { addr = "10.0.0.1"; inherit port; }) ([ 80 ] ++ lib.attrValues sites) ++ [{ addr = "10.0.0.1"; port = 443; ssl = true; }];
        extraConfig = "ssl_reject_handshake on;";
        locations."/".return = "444";
      };
    };

    systemd.services.bincert = {
      wantedBy = [ "multi-user.target" ];
      before = [ "nginx.service" ];
      path = [ pkgs.openssl pkgs.coreutils pkgs.systemd ];
      script = ''
        umask 027
        cd ${certs}
        names="${san}"
        if [ ! -s ca.key ]; then
          openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out ca.key
          chmod 600 ca.key
          openssl req -x509 -new -key ca.key -sha256 -days 3650 -subj "/CN=bin" \
            -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
            -addext "keyUsage=critical,keyCertSign,cRLSign" \
            -addext "nameConstraints=critical,permitted;DNS:bin" -out ca.crt
          rm -f bin.crt
        fi
        if [ ! -s bin.crt ] || [ "$(cat names 2>/dev/null)" != "$names" ] || ! openssl x509 -checkend 2592000 -noout -in bin.crt >/dev/null; then
          openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out new.key
          printf 'subjectAltName=%s\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\n' "$names" > ext
          openssl req -new -key new.key -subj "/CN=bin" | openssl x509 -req -CA ca.crt -CAkey ca.key -set_serial "0x$(openssl rand -hex 16)" -days 397 -sha256 -extfile ext -out new.crt
          chmod 640 new.key
          mv new.key bin.key
          mv new.crt bin.crt
          printf '%s' "$names" > names
          rm ext
          chmod 644 ca.crt bin.crt
          systemctl --no-block try-reload-or-restart nginx.service
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        Group = "nginx";
        StateDirectory = "bincert";
        StateDirectoryMode = "0750";
      };
    };

    systemd.timers.bincert = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    systemd.services.nginx = {
      wants = [ "bincert.service" ];
      after = [ "bincert.service" ];
    };

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        listen-address = "10.0.0.1";
        bind-dynamic = true;
        no-resolv = true;
        no-hosts = true;
        addn-hosts = "${pkgs.writeText "hosts" (lib.concatStrings (lib.mapAttrsToList (ip: names: "${ip} ${toString names}\n") (lib.filterAttrs (ip: _: lib.hasPrefix "10.0.0." ip) config.networking.hosts)))}";
        server = [ "1.1.1.1" "8.8.8.8" ];
        domain-needed = true;
        bogus-priv = true;
      };
    };

    environment.etc."dash/services.json".text = builtins.toJSON {
      units = lib.concatLists (lib.mapAttrsToList (_: s: map (unit: { inherit unit; inherit (s) link; port = if s.site == null then null else sites.${s.site}; site = s.site; }) s.units) config.network.services);
      storage = lib.concatLists (lib.mapAttrsToList (_: s: lib.mapAttrsToList (name: path: { inherit name path; }) s.data) config.network.services);
    };
  };
}
