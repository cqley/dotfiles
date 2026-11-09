import { timingSafeEqual } from "node:crypto";

const home = "/var/lib/navidrome";
const musicDir = `${home}/music`;
const tmpRoot = `${home}/tmp`;
const tokenFile = `${home}/.downloadertoken`;

const sources = {
  youtube: ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"],
  spotify: ["open.spotify.com"],
  soundcloud: ["soundcloud.com", "www.soundcloud.com", "m.soundcloud.com", "on.soundcloud.com"],
};
const spotifyPath = /^\/(intl-[a-z]{2}(-[a-z]{2})?\/)?(track|album|playlist|artist)\/[A-Za-z0-9]+\/?$/;

async function ensureToken() {
  try {
    return (await Deno.readTextFile(tokenFile)).trim();
  } catch {
    const t = Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, "0")).join("");
    await Deno.writeTextFile(tokenFile, t, { mode: 0o600 });
    console.log("new downloader token written to " + tokenFile);
    return t;
  }
}
const token = await ensureToken();

async function digest(s) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
}
const tokenDigest = await digest(`bearer ${token}`);

async function authed(req) {
  return timingSafeEqual(await digest(req.headers.get("authorization") ?? ""), tokenDigest);
}

function checkUrl(raw) {
  if (typeof raw !== "string" || raw.length > 2048) return null;
  let u;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" && u.protocol !== "http:") return null;
  if (u.username || u.password || u.port) return null;
  const host = u.hostname.toLowerCase();
  const source = Object.keys(sources).find((s) => sources[s].includes(host));
  if (!source) return null;
  if (source === "spotify" && !spotifyPath.test(u.pathname)) return null;
  u.protocol = "https:";
  u.hash = "";
  return { source, url: u.href };
}

function command(source, url, type, outDir) {
  if (source === "spotify") {
    return {
      cmd: "spotdl",
      args: ["download", url, "--output", outDir, "--format", "mp3"],
    };
  }
  const args = ["-x", "--audio-format", "mp3", "--embed-metadata", "--embed-thumbnail", "-o", "%(title)s.%(ext)s", "-P", outDir];
  if (type === "song") args.push("--no-playlist");
  args.push("--", url);
  return { cmd: "yt-dlp", args };
}

async function run(cmd, args, cwd) {
  const { code, stdout, stderr } = await new Deno.Command(cmd, { args, cwd, stdin: "null" }).output();
  const dec = new TextDecoder();
  return { ok: code === 0, log: dec.decode(stdout) + dec.decode(stderr) };
}

async function cleanTmp() {
  await Deno.mkdir(tmpRoot, { recursive: true });
  for await (const e of Deno.readDir(tmpRoot)) {
    const p = `${tmpRoot}/${e.name}`;
    const info = await Deno.stat(p).catch(() => null);
    if (info && Date.now() - info.mtime.getTime() > 3600_000) {
      await Deno.remove(p, { recursive: true }).catch(() => {});
    }
  }
}

function attachment(name) {
  const ascii = name.replace(/[^\x20-\x7e]|["\\]/g, "_");
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(name)}`;
}

async function sendToDevice(source, url, type) {
  await cleanTmp();
  const tmp = await Deno.makeTempDir({ dir: tmpRoot });
  const outDir = `${tmp}/out`;
  await Deno.mkdir(outDir);
  const { cmd, args } = command(source, url, type, outDir);
  const result = await run(cmd, args, tmp);

  const files = [];
  for await (const e of Deno.readDir(outDir)) {
    if (e.isFile && e.name.endsWith(".mp3")) files.push(e.name);
  }
  if (files.length === 0) {
    await Deno.remove(tmp, { recursive: true }).catch(() => {});
    return new Response("error\n\n" + result.log, { status: 422 });
  }

  let path, name, mime;
  if (files.length === 1) {
    path = `${outDir}/${files[0]}`;
    name = files[0];
    mime = "audio/mpeg";
  } else {
    path = `${tmp}/music.zip`;
    name = "music.zip";
    mime = "application/zip";
    const zipped = await run("zip", ["-0", "-j", "-q", path, ...files.map((f) => `${outDir}/${f}`)], tmp);
    if (!zipped.ok) {
      await Deno.remove(tmp, { recursive: true }).catch(() => {});
      return new Response("error\n\n" + zipped.log, { status: 500 });
    }
  }

  const file = await Deno.open(path);
  const size = (await file.stat()).size;
  const body = file.readable.pipeThrough(new TransformStream({
    flush() {
      Deno.remove(tmp, { recursive: true }).catch(() => {});
    },
  }));
  return new Response(body, {
    headers: {
      "content-type": mime,
      "content-length": String(size),
      "content-disposition": attachment(name),
    },
  });
}

async function sendToServer(source, url, type) {
  const { cmd, args } = command(source, url, type, musicDir);
  const result = await run(cmd, args, home);
  return new Response((result.ok ? "success\n\n" : "error\n\n") + result.log, { status: result.ok ? 200 : 422 });
}

const page = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>楽</title>
  <link rel="icon" type="image/svg+xml" href="/assets/cat.svg">
  <link rel="stylesheet" href="/assets/style.css">
  <style>
    .row{display:flex;flex-wrap:wrap;gap:.5rem;}
    .row select{flex:1;min-width:0;}
    .row button{align-self:stretch;}
    #url{width:100%;min-width:0;}
    #out{color:var(--dim);border:1px solid var(--line);padding:.5rem;max-height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-all;display:none;font-size:.85em;margin-top:1.5rem;}
  </style>
</head>
<body>
  <main class="wrap">
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">music</h1>
    <form id="login">
      <input id="pw" type="password" placeholder="token" autocomplete="off">
      <button type="submit">unlock</button>
    </form>
    <div id="app" style="display:none">
      <p class="muted">downloader &lt;3</p>
      <h2>fetch</h2>
      <form id="f">
        <input type="url" id="url" placeholder="link" required autocomplete="off">
        <div class="row">
          <select id="type">
            <option value="song">song</option>
            <option value="playlist">playlist</option>
          </select>
          <select id="dest">
            <option value="server">server</option>
            <option value="device">device</option>
          </select>
          <button type="submit" id="btn">download</button>
        </div>
      </form>
      <div id="status" class="status">ready</div>
      <pre id="out"></pre>
    </div>
  </main>
  <script>
    const store = {
      get(k) { try { return localStorage.getItem(k) || ""; } catch { return ""; } },
      set(k, v) { try { localStorage.setItem(k, v); } catch {} },
      del(k) { try { localStorage.removeItem(k); } catch {} },
    };
    let token = store.get("downloadertoken");

    const login = document.getElementById("login");
    const pw = document.getElementById("pw");
    const app = document.getElementById("app");
    const f = document.getElementById("f");
    const urlInput = document.getElementById("url");
    const typeSelect = document.getElementById("type");
    const destSelect = document.getElementById("dest");
    const btn = document.getElementById("btn");
    const out = document.getElementById("out");
    const status = document.getElementById("status");

    destSelect.value = store.get("downloaderdest") || "server";
    destSelect.onchange = () => store.set("downloaderdest", destSelect.value);

    urlInput.addEventListener("input", (e) => {
      const val = e.target.value;
      if (val.includes("playlist") || val.includes("&list=") || val.includes("/album/") || val.includes("/sets/")) {
        typeSelect.value = "playlist";
      }
    });

    login.onsubmit = (e) => {
      e.preventDefault();
      token = pw.value;
      store.set("downloadertoken", token);
      boot();
    };

    function filename(res) {
      const cd = res.headers.get("content-disposition") || "";
      const star = cd.match(/filename\\*=UTF-8''([^;]+)/);
      if (star) return decodeURIComponent(star[1]);
      const plain = cd.match(/filename="([^"]+)"/);
      return plain ? plain[1] : "music";
    }

    function setBusy(busy) {
      btn.disabled = busy;
      urlInput.disabled = busy;
      typeSelect.disabled = busy;
      destSelect.disabled = busy;
    }

    f.onsubmit = async (e) => {
      e.preventDefault();
      setBusy(true);
      out.style.display = "none";
      out.textContent = "";
      status.textContent = "processing...";
      status.className = "status";

      try {
        const res = await fetch("dl", {
          method: "POST",
          headers: { authorization: "bearer " + token, "content-type": "application/json" },
          body: JSON.stringify({ url: urlInput.value, type: typeSelect.value, dest: destSelect.value }),
        });
        if (res.status === 401) {
          token = "";
          store.del("downloadertoken");
          boot();
          return;
        }
        if (res.ok && res.headers.get("content-disposition")) {
          status.textContent = "saving...";
          const blob = await res.blob();
          const a = document.createElement("a");
          a.href = URL.createObjectURL(blob);
          a.download = filename(res);
          document.body.appendChild(a);
          a.click();
          a.remove();
          setTimeout(() => URL.revokeObjectURL(a.href), 60000);
          status.textContent = "saved to your device";
          status.className = "status ok";
          urlInput.value = "";
          return;
        }
        const text = await res.text();
        out.style.display = "block";
        out.textContent = text;
        if (res.ok && text.startsWith("success")) {
          status.textContent = "download complete";
          status.className = "status ok";
          urlInput.value = "";
        } else {
          status.textContent = "process failed";
          status.className = "status err";
        }
      } catch (err) {
        out.style.display = "block";
        out.textContent = err;
        status.textContent = "network error";
        status.className = "status err";
      } finally {
        setBusy(false);
        urlInput.focus();
      }
    };

    async function boot() {
      if (!token) {
        login.style.display = "flex";
        app.style.display = "none";
        return;
      }
      const res = await fetch("check", { headers: { authorization: "bearer " + token } });
      if (res.ok) {
        login.style.display = "none";
        app.style.display = "block";
        urlInput.focus();
      } else {
        token = "";
        store.del("downloadertoken");
        login.style.display = "flex";
        app.style.display = "none";
      }
    }
    boot();
  </script>
</body>
</html>
`;

let busy = false;

Deno.serve({ port: 4534, hostname: "127.0.0.1" }, async (req) => {
  const path = new URL(req.url).pathname;

  if (req.method === "GET" && path === "/check") {
    return (await authed(req)) ? new Response("ok") : new Response("unauthorized", { status: 401 });
  }
  if (req.method === "GET" && path === "/") {
    return new Response(page, { headers: { "content-type": "text/html; charset=utf-8" } });
  }
  if (req.method === "POST" && path === "/dl") {
    if (!(await authed(req))) return new Response("unauthorized", { status: 401 });
    if (Number(req.headers.get("content-length") ?? 0) > 4096) return new Response("error\n\nrequest too large", { status: 413 });

    let body;
    try {
      body = await req.json();
    } catch {
      return new Response("error\n\ninvalid request", { status: 400 });
    }
    const checked = checkUrl(body?.url);
    if (!checked) return new Response("error\n\nonly youtube, spotify and soundcloud links are allowed", { status: 400 });
    const type = body.type === "playlist" ? "playlist" : "song";
    const dest = body.dest === "device" ? "device" : "server";

    if (busy) return new Response("error\n\nanother download is running, try again in a bit", { status: 429 });
    busy = true;
    try {
      return dest === "device"
        ? await sendToDevice(checked.source, checked.url, type)
        : await sendToServer(checked.source, checked.url, type);
    } catch (err) {
      return new Response("error\n\n" + err, { status: 500 });
    } finally {
      busy = false;
    }
  }
  return new Response("not found", { status: 404 });
});
