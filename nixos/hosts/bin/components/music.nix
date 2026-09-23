{ config, pkgs, ... }:

let
  dl-server = pkgs.writeText "dl-server.js" ''
    const tokenFile = "/var/lib/navidrome/.downloader-token";
    async function ensureToken() {
      try {
        return (await Deno.readTextFile(tokenFile)).trim();
      } catch {
        const t = crypto.randomUUID().replaceAll("-", "");
        await Deno.writeTextFile(tokenFile, t);
        console.log(`downloader token: ''${t}`);
        return t;
      }
    }
    const token = await ensureToken();
    function authed(req) {
      return req.headers.get("authorization") === `bearer ''${token}`;
    }

    Deno.serve({ port: 4534, hostname: "127.0.0.1" }, async (req) => {
      if (req.method === "GET" && new URL(req.url).pathname === "/check") {
        return authed(req) ? new Response("ok") : new Response("unauthorized", { status: 401 });
      }
      if (req.method === "GET") {
        return new Response(`
          <!doctype html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>music</title>
            <style>
              :root{--bg:#fff;--fg:#222;--dim:#888;--acc:#f2b8e2;--line:#ddd;--err:#e33;}
              *{box-sizing:border-box}
              body{background:var(--bg);color:var(--fg);font-family:ui-monospace,monospace;font-size:15px;line-height:1.5;max-width:60ch;margin:4rem auto;padding:0 1rem;}
              h1{font-size:1rem;font-weight:normal;margin:0 0 .5rem}
              h2{font-size:.9rem;font-weight:normal;color:var(--dim);margin:2rem 0 .5rem;border-bottom:1px solid var(--line);padding-bottom:.3rem}
              p{margin:0 0 1rem;color:var(--dim)}
              form{display:flex;flex-direction:column;gap:.5rem;}
              .row{display:flex;gap:.5rem;}
              input,select,button{font-family:inherit;font-size:inherit;background:var(--bg);color:var(--fg);border:1px solid var(--line);padding:.3rem .5rem;outline:none;border-radius:0;}
              input:focus,select:focus,button:focus{border-color:var(--acc);}
              input{flex:1;}
              button{color:var(--acc);cursor:pointer;}
              button:hover{border-color:var(--acc);}
              button:disabled{opacity:.5;cursor:not-allowed;}
              #out{color:var(--dim);border:1px solid var(--line);padding:.5rem;max-height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-all;display:none;font-size:.85em;margin-top:2rem;}
              .status{color:var(--dim);font-size:.9em;margin-top:.5rem;}
              .status.success{color:var(--acc);}
              .status.error{color:var(--err);}
            </style>
          </head>
          <body>
            <h1>music</h1>
            <form id="login">
              <input id="pw" type="password" placeholder="token" autocomplete="off">
              <button type="submit">unlock</button>
            </form>
            <div id="app" style="display:none">
              <p>music downloader &lt;3</p>
              <h2>fetch</h2>
              <form id="f">
                <div class="row">
                  <input type="url" id="url" placeholder="link" required autocomplete="off">
                  <select id="type">
                    <option value="song">song</option>
                    <option value="playlist">playlist</option>
                  </select>
                </div>
                <button type="submit" id="btn">download</button>
              </form>
              <div id="status" class="status">ready</div>
              <pre id="out"></pre>
            </div>
            <script>
              let token = localStorage.getItem('downloader-token') || "";

              const login = document.getElementById('login');
              const pw = document.getElementById('pw');
              const app = document.getElementById('app');

              const f = document.getElementById('f');
              const urlInput = document.getElementById('url');
              const typeSelect = document.getElementById('type');
              const btn = document.getElementById('btn');
              const out = document.getElementById('out');
              const status = document.getElementById('status');

              urlInput.addEventListener('input', (e) => {
                const val = e.target.value;
                if (val.includes('playlist') || val.includes('&list=')) {
                  typeSelect.value = 'playlist';
                }
              });

              login.onsubmit = (e) => {
                e.preventDefault();
                token = pw.value;
                localStorage.setItem('downloader-token', token);
                boot();
              };

              f.onsubmit = async (e) => {
                e.preventDefault();
                btn.disabled = true;
                urlInput.disabled = true;
                typeSelect.disabled = true;
                out.style.display = 'block';
                out.textContent = "";
                status.textContent = 'processing...';
                status.className = 'status';

                try {
                  const res = await fetch('dl', {
                    method: 'POST',
                    headers: { authorization: 'bearer ' + token },
                    body: JSON.stringify({ url: urlInput.value, type: typeSelect.value })
                  });
                  if (res.status === 401) {
                    token = "";
                    localStorage.removeItem('downloader-token');
                    boot();
                    return;
                  }
                  const text = await res.text();
                  out.textContent = text;

                  if (text.startsWith('success')) {
                    status.textContent = 'download complete';
                    status.className = 'status success';
                    urlInput.value = "";
                  } else {
                    status.textContent = 'process failed';
                    status.className = 'status error';
                  }
                } catch (err) {
                  out.textContent = err;
                  status.textContent = 'network error';
                  status.className = 'status error';
                } finally {
                  btn.disabled = false;
                  urlInput.disabled = false;
                  typeSelect.disabled = false;
                  urlInput.focus();
                }
              };

              async function boot() {
                if (!token) {
                  login.style.display = 'flex';
                  app.style.display = 'none';
                  return;
                }
                const res = await fetch('check', { headers: { authorization: 'bearer ' + token } });
                if (res.ok) {
                  login.style.display = 'none';
                  app.style.display = 'block';
                  urlInput.focus();
                } else {
                  token = "";
                  localStorage.removeItem('downloader-token');
                  login.style.display = 'flex';
                  app.style.display = 'none';
                }
              }
              boot();
            </script>
          </body>
          </html>
        `, { headers: { "content-type": "text/html" } });
      }
      if (req.method === "POST" && new URL(req.url).pathname === "/dl") {
        const { url, type } = await req.json();
        let cmd;
        if (url.includes("spotify.com")) {
          const args = ["download", url, "--output", "/var/lib/navidrome/music", "--format", "mp3"];
          cmd = new Deno.Command("${pkgs.spotdl}/bin/spotdl", {
            args,
            env: {
              HOME: "/var/lib/navidrome",
              XDG_CONFIG_HOME: "/var/lib/navidrome/.config",
              XDG_CACHE_HOME: "/var/lib/navidrome/.cache"
            }
          });
        } else {
          const args = ["-x", "--audio-format", "mp3", "--embed-metadata", "--embed-thumbnail", "-o", "%(title)s.%(ext)s", "-P", "/var/lib/navidrome/music"];
          if (type === "song") args.push("--no-playlist");
          args.push(url);
          cmd = new Deno.Command("${pkgs.yt-dlp}/bin/yt-dlp", { args });
        }
        const { code, stdout, stderr } = await cmd.output();
        const dec = new TextDecoder();
        return new Response((code === 0 ? "success\n\n" : "error\n\n") + dec.decode(stdout) + dec.decode(stderr));
      }
      return new Response("not found", { status: 404 });
    });
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 4533 ];

  services.navidrome = {
    enable = true;
    settings = {
      Address = "127.0.0.1";
      Port = 4533;
      MusicFolder = "/var/lib/navidrome/music";
    };
  };

  environment.systemPackages = [
    pkgs.ffmpeg
    pkgs.deno
    pkgs.spotdl
    (pkgs.writeShellScriptBin "music" ''
      [[ $# -lt 2 ]] && { echo "usage: music [song|playlist] url"; exit 1; }
      if [[ "$2" == *"spotify.com"* ]]; then
        exec doas -u navidrome env HOME=/var/lib/navidrome XDG_CONFIG_HOME=/var/lib/navidrome/.config ${pkgs.spotdl}/bin/spotdl download "$2" --output /var/lib/navidrome/music --format mp3
      else
        args=(-x --audio-format mp3 --embed-metadata --embed-thumbnail -o '%(title)s.%(ext)s' -P /var/lib/navidrome/music)
        [[ $1 == "song" ]] && args+=(--no-playlist)
        exec doas -u navidrome ${pkgs.yt-dlp}/bin/yt-dlp "''${args[@]}" "$2"
      fi
    '')
  ];

  systemd.services.music-web = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.yt-dlp pkgs.ffmpeg pkgs.deno pkgs.spotdl ];
    environment = {
      HOME = "/var/lib/navidrome";
      XDG_CONFIG_HOME = "/var/lib/navidrome/.config";
      XDG_CACHE_HOME = "/var/lib/navidrome/.cache";
    };
    script = ''
      exec ${pkgs.deno}/bin/deno run \
        --allow-net \
        --allow-run \
        --allow-read \
        --allow-write \
        --allow-env \
        ${dl-server}
    '';
    serviceConfig = {
      User = "navidrome";
      WorkingDirectory = "/var/lib/navidrome";
    };
  };

  systemd.services.edeltalk = {
    script = ''
      ${pkgs.yt-dlp}/bin/yt-dlp -x --audio-format mp3 --embed-metadata --embed-thumbnail \
        --playlist-items 1 \
        -o "%(title)s.%(ext)s" \
        -P /var/lib/navidrome/music \
        "https://music.youtube.com/playlist?list=PL_PrOB576HxI0mXdEVlBRpB2zerTAGCss"
    '';
    path = [ pkgs.yt-dlp pkgs.ffmpeg pkgs.deno ];
    serviceConfig = {
      Type = "oneshot";
      User = "navidrome";
    };
    startAt = "*:0/3";
  };

  systemd.services.unfassbar = {
    script = ''
      ${pkgs.yt-dlp}/bin/yt-dlp -x --audio-format mp3 --embed-metadata --embed-thumbnail \
        --playlist-items 1 \
        -o "%(title)s.%(ext)s" \
        -P /var/lib/navidrome/music \
        "https://music.youtube.com/playlist?list=PLEjgu53NfIVDFSb4HV3Qj7-IF4TQlXBNp"
    '';
    path = [ pkgs.yt-dlp pkgs.ffmpeg pkgs.deno ];
    serviceConfig = {
      Type = "oneshot";
      User = "navidrome";
    };
    startAt = "*:0/3";
  };
}