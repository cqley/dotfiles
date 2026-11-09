const root = "/var/lib/minecraft";
const portFrom = 25565;
const portTo = 25580;
const packUrl = "https://1f2t.org/packs";
let servers = {};
let names = new Set();
const reserved = ["backups", "dashboard", "api", "static", "assets", "app"];
const validName = (n) => typeof n === "string" && /^[a-z0-9]{1,16}$/.test(n) && !reserved.includes(n);
async function reload() {
  const next = {};
  for await (const e of Deno.readDir(root)) {
    if (!e.isDirectory || !validName(e.name)) continue;
    const c = await Deno.readTextFile(`${root}/${e.name}/server.json`).then(JSON.parse).catch(() => null);
    if (c && typeof c === "object") next[e.name] = { ...c, packUrl };
  }
  servers = next;
  names = new Set(Object.keys(next).sort());
}
await reload().catch(() => {});
setInterval(() => reload().catch(() => {}), 10000);
const histFile = "/var/lib/mcpanel/history.json";
const agent = "silly-panel (github.com/cqley/dotfiles)";
const enc = new TextEncoder();
const dec = new TextDecoder();
const cpuPrev = {};
const samplePrev = {};
const bytes = (m) => Number(m.slice(0, -1)) * (m.endsWith("G") ? 1073741824 : 1048576);
const validPlayer = (p) => typeof p === "string" && /^[A-Za-z0-9_]{1,16}$/.test(p);
const validBackup = (f) => typeof f === "string" && /^\d+\.tar\.gz$/.test(f);

async function run(cmd, args) {
  const { code, stdout, stderr } = await new Deno.Command(cmd, { args, stdin: "null" }).output();
  return { ok: code === 0, out: dec.decode(stdout), err: dec.decode(stderr) };
}

async function show(unit, props) {
  const { out } = await run("systemctl", ["show", unit, "--timestamp=unix", "-p", props.join(",")]);
  return Object.fromEntries(out.trim().split("\n").filter(Boolean).map((l) => {
    const i = l.indexOf("=");
    return [l.slice(0, i), l.slice(i + 1)];
  }));
}

const stamp = (v) => v?.startsWith("@") ? Number(v.slice(1)) * 1000 : null;

function varint(n) {
  const o = [];
  do {
    let b = n & 0x7f;
    n >>>= 7;
    if (n) b |= 0x80;
    o.push(b);
  } while (n);
  return o;
}

function packet(id, body) {
  const d = [...varint(id), ...body];
  return new Uint8Array([...varint(d.length), ...d]);
}

async function ping(port) {
  const conn = await Deno.connect({ hostname: "127.0.0.1", port });
  const timer = setTimeout(() => { try { conn.close(); } catch {} }, 2000);
  try {
    const host = enc.encode("127.0.0.1");
    await conn.write(packet(0, [...varint(767), ...varint(host.length), ...host, port >> 8, port & 255, 1]));
    await conn.write(packet(0, []));
    let buf = new Uint8Array(0);
    let pos = 0;
    const chunk = new Uint8Array(65536);
    const need = async (n) => {
      while (buf.length < n) {
        const r = await conn.read(chunk);
        if (r === null) throw new Error("eof");
        const nb = new Uint8Array(buf.length + r);
        nb.set(buf);
        nb.set(chunk.subarray(0, r), buf.length);
        buf = nb;
      }
    };
    const rv = async () => {
      let n = 0;
      for (let s = 0; s < 35; s += 7) {
        await need(pos + 1);
        const b = buf[pos++];
        n |= (b & 0x7f) << s;
        if (!(b & 0x80)) return n;
      }
      throw new Error("varint");
    };
    const len = await rv();
    await need(pos + len);
    await rv();
    const sl = await rv();
    return JSON.parse(dec.decode(buf.subarray(pos, pos + sl)));
  } finally {
    clearTimeout(timer);
    try { conn.close(); } catch {}
  }
}

async function onlineFromLog(name, since) {
  const { out } = await run("journalctl", ["-u", `minecraft@${name}.service`, "--since", `@${Math.floor(since / 1000)}`, "-o", "cat", "--no-pager", "-g", "(joined|left) the game$"]);
  const set = new Set();
  for (const l of out.split("\n")) {
    const m = l.match(/\]: (?:System chat: )?(\w{1,16}) (joined|left) the game$/);
    if (!m) continue;
    if (m[2] === "joined") set.add(m[1]);
    else set.delete(m[1]);
  }
  return [...set];
}

async function status(name, prevMap = cpuPrev) {
  const s = servers[name];
  const p = await show(`minecraft@${name}.service`, ["ActiveState", "MemoryCurrent", "CPUUsageNSec", "ActiveEnterTimestamp"]);
  const now = Date.now();
  const ns = Number(p.CPUUsageNSec) || 0;
  let cpu = 0;
  const prev = prevMap[name];
  if (prev && ns >= prev.ns && now > prev.t) cpu = (ns - prev.ns) / 1e6 / (now - prev.t) * 100;
  prevMap[name] = { ns, t: now };
  const mem = Number(p.MemoryCurrent);
  const active = p.ActiveState === "active";
  let info = null;
  if (active) info = await ping(s.port).catch(() => null);
  const since = active ? stamp(p.ActiveEnterTimestamp) : null;
  const online = info && since ? await onlineFromLog(name, since) : null;
  const lagging = info ? await lag(name) : null;
  const saved = info ? Number((await Deno.readTextFile(`${root}/${name}/server.properties`).catch(() => "")).match(/^max-players=(\d+)/m)?.[1]) : NaN;
  return {
    name,
    port: s.port,
    version: s.version,
    type: s.type,
    loader: s.loader,
    autostart: s.autostart !== false,
    public: s.public !== false,
    backup: s.backup ?? null,
    restart: s.restart ?? null,
    memory: s.memory,
    limit: bytes(s.memory),
    state: p.ActiveState,
    ready: !!info,
    used: Number.isFinite(mem) ? mem : 0,
    cpu: Math.round(cpu),
    since,
    lag: lagging,
    icon: (await Deno.stat(`${root}/${name}/server-icon.png`).catch(() => null))?.mtime?.getTime() ?? null,
    players: info ? {
      online: online ? online.length : info.players?.online ?? 0,
      max: info.players?.max ?? 0,
      pendingMax: Number.isFinite(saved) && saved !== info.players?.max ? saved : null,
      list: online ?? (info.players?.sample ?? []).map((x) => x.name),
    } : null,
  };
}

function nextAt(hm) {
  if (!validTime(hm) || hm === null) return null;
  const [h, m] = hm.split(":").map(Number);
  const d = new Date();
  d.setHours(h, m, 0, 0);
  if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
  return d.getTime();
}

async function tasks(name) {
  const [b, r] = await Promise.all([
    show(`minecraft-backup@${name}.service`, ["ActiveState", "Result"]),
    show(`minecraft-restart@${name}.service`, ["ActiveState"]),
  ]);
  const c = servers[name];
  return {
    backup: { state: b.ActiveState, result: b.Result, next: nextAt(c.backup ?? null), at: c.backup ?? null },
    restart: { state: r.ActiveState, next: nextAt(c.restart ?? null), at: c.restart ?? null },
  };
}

const validTime = (t) => t === null || (typeof t === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(t));
const validMemory = (m) => typeof m === "string" && /^([1-9]|1[0-6])G$/.test(m);
const metaCache = new Map();
const manifestUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json";

async function cachedJson(url, ttl = 3600000) {
  const c = metaCache.get(url);
  if (c && Date.now() - c.t < ttl) return c.v;
  const r = await fetch(url, { headers: { "user-agent": agent } });
  if (!r.ok) throw new Error(`${new URL(url).host}: ${r.status}`);
  const v = await r.json();
  metaCache.set(url, { t: Date.now(), v });
  return v;
}

async function versionList(type) {
  const m = await cachedJson(manifestUrl);
  let list = m.versions.filter((v) => v.type === "release").map((v) => v.id);
  if (type === "fabric") {
    const g = new Set((await cachedJson("https://meta.fabricmc.net/v2/versions/game")).filter((x) => x.stable).map((x) => x.version));
    list = list.filter((v) => g.has(v));
  }
  return list;
}

async function versionInfo(version) {
  const m = await cachedJson(manifestUrl);
  const v = m.versions.find((x) => x.id === version && x.type === "release");
  if (!v || !v.url.startsWith("https://piston-meta.mojang.com/")) throw new Error("unknown version");
  const j = await cachedJson(v.url, 86400000);
  const major = j.javaVersion?.majorVersion ?? 8;
  return { server: j.downloads?.server ?? null, java: major <= 8 ? 8 : major <= 17 ? 17 : major <= 21 ? 21 : 25 };
}

async function download(url, hash) {
  const r = await fetch(url, { headers: { "user-agent": agent } });
  if (!r.ok) throw new Error(`download failed: ${r.status}`);
  const data = new Uint8Array(await r.arrayBuffer());
  if (hash && await sha1(data) !== hash) throw new Error("download corrupted");
  return data;
}

async function fetchJar(type, version) {
  const info = await versionInfo(version);
  if (type === "vanilla") {
    if (!info.server?.url?.startsWith("https://piston-data.mojang.com/")) throw new Error("no server jar for this version");
    return { data: await download(info.server.url, info.server.sha1), java: info.java, loader: null };
  }
  const loaders = await cachedJson(`https://meta.fabricmc.net/v2/versions/loader/${encodeURIComponent(version)}`, 600000);
  const loader = (loaders.find((l) => l.loader?.stable) ?? loaders[0])?.loader?.version;
  if (!loader) throw new Error("no fabric for this version");
  const installer = (await cachedJson("https://meta.fabricmc.net/v2/versions/installer", 600000)).find((i) => i.stable)?.version;
  if (!installer) throw new Error("no fabric installer");
  const data = await download(`https://meta.fabricmc.net/v2/versions/loader/${encodeURIComponent(version)}/${encodeURIComponent(loader)}/${encodeURIComponent(installer)}/server/jar`);
  if (data[0] !== 0x50 || data[1] !== 0x4b) throw new Error("fabric download is not a jar");
  return { data, java: info.java, loader };
}

async function own(path, mode) {
  await Deno.chown(path, null, (await Deno.stat(root)).gid);
  await Deno.chmod(path, mode);
}

async function writeFileAs(path, data, mode = 0o660) {
  if (typeof data === "string") await Deno.writeTextFile(`${path}.part`, data);
  else await Deno.writeFile(`${path}.part`, data);
  await own(`${path}.part`, mode);
  await Deno.rename(`${path}.part`, path);
}

const configKeys = ["type", "version", "loader", "java", "memory", "port", "backup", "restart", "autostart", "public"];
const writeConfig = (name, c) => writeFileAs(`${root}/${name}/server.json`, JSON.stringify(Object.fromEntries(configKeys.map((k) => [k, c[k] ?? null])), null, 2) + "\n");

function freePort(want) {
  const used = new Set(Object.values(servers).map((c) => c.port));
  if (want != null) {
    if (!Number.isInteger(want) || want < portFrom || want > portTo) throw new Error(`port must be ${portFrom}–${portTo}`);
    if (used.has(want)) throw new Error("port taken");
    return want;
  }
  for (let p = portFrom; p <= portTo; p++) if (!used.has(p)) return p;
  throw new Error("no free port");
}

function checkSchedule(b) {
  for (const k of ["backup", "restart"]) if (b[k] !== undefined && !validTime(b[k])) throw new Error(`${k}: use hh:mm or empty`);
}

async function createServer(b) {
  const { name, type, version, memory } = b ?? {};
  if (!validName(name)) throw new Error("name: a–z and 0–9, up to 16");
  if (names.has(name) || await Deno.stat(`${root}/${name}`).then(() => true, () => false)) throw new Error("name taken");
  if (!["vanilla", "fabric"].includes(type)) throw new Error("unknown type");
  if (!validMemory(memory)) throw new Error("memory: 1G to 16G");
  checkSchedule(b);
  const port = freePort(b.port ?? null);
  const jar = await fetchJar(type, version);
  const dir = `${root}/${name}`;
  await Deno.mkdir(dir);
  try {
    await own(dir, 0o2770);
    await writeFileAs(`${dir}/server.jar`, jar.data);
    await writeFileAs(`${dir}/server.properties`, `server-port=${port}\nmotd=${name}\n`);
    await writeConfig(name, { type, version, loader: jar.loader, java: jar.java, memory, port, backup: b.backup ?? null, restart: b.restart ?? null, autostart: b.autostart !== false, public: b.public !== false });
  } catch (e) {
    await Deno.remove(dir, { recursive: true }).catch(() => {});
    throw e;
  }
  await reload();
  if (b.start) await run("systemctl", ["start", "--no-block", `minecraft@${name}.service`]);
  return { name, port };
}

async function updateServer(name, b) {
  const c = { ...servers[name] };
  if (b.memory !== undefined) { if (!validMemory(b.memory)) throw new Error("memory: 1G to 16G"); c.memory = b.memory; }
  checkSchedule(b);
  for (const k of ["backup", "restart"]) if (b[k] !== undefined) c[k] = b[k];
  for (const k of ["autostart", "public"]) if (b[k] !== undefined) c[k] = !!b[k];
  if (b.port !== undefined && b.port !== c.port) c.port = freePort(b.port);
  if (b.version !== undefined && b.version !== c.version) {
    if ((await show(`minecraft@${name}.service`, ["ActiveState"])).ActiveState !== "inactive") throw new Error("stop the server first");
    const jar = await fetchJar(c.type, b.version);
    await writeFileAs(`${root}/${name}/server.jar`, jar.data);
    Object.assign(c, { version: b.version, loader: jar.loader, java: jar.java });
  }
  await writeConfig(name, c);
  await reload();
  return c;
}

function logs(name, req) {
  const child = new Deno.Command("journalctl", {
    args: ["-u", `minecraft@${name}.service`, "-f", "-n", "300", "-o", "cat", "--no-pager"],
    stdin: "null",
    stdout: "piped",
    stderr: "null",
  }).spawn();
  req.signal.addEventListener("abort", () => { try { child.kill(); } catch {} });
  let buf = "";
  const body = child.stdout.pipeThrough(new TextDecoderStream()).pipeThrough(new TransformStream({
    start(ctl) { ctl.enqueue(enc.encode(": open\n\n")); },
    transform(chunk, ctl) {
      buf += chunk;
      const lines = buf.split("\n");
      buf = lines.pop();
      for (const l of lines) ctl.enqueue(enc.encode(`data: ${l}\n\n`));
    },
  }));
  return new Response(body, { headers: { "content-type": "text/event-stream", "cache-control": "no-cache", "x-accel-buffering": "no" } });
}

async function command(name, text) {
  const line = text.replace(/[\r\n]+/g, " ").trim().replace(/^\//, "");
  if (!line) return false;
  const f = await Deno.open(`/run/minecraft/${name}.stdin`, { write: true });
  try { await f.write(enc.encode(line + "\n")); } finally { f.close(); }
  return true;
}

async function backups(name) {
  const dir = `${root}/backups/${name}`;
  const out = [];
  try {
    for await (const e of Deno.readDir(dir)) {
      if (!e.isFile || !validBackup(e.name)) continue;
      const st = await Deno.stat(`${dir}/${e.name}`);
      out.push({ file: e.name, size: st.size, time: st.mtime?.getTime() ?? 0 });
    }
  } catch {}
  return out.sort((a, b) => b.time - a.time);
}

async function readJson(path) {
  try { return JSON.parse(await Deno.readTextFile(path)); } catch { return []; }
}

async function playerData(name) {
  const dir = `${root}/${name}`;
  const props = await Deno.readTextFile(`${dir}/server.properties`).catch(() => "");
  return {
    whitelist: {
      enabled: /^white-list=true\s*$/m.test(props),
      list: (await readJson(`${dir}/whitelist.json`)).map((x) => x.name).sort(),
    },
    ops: (await readJson(`${dir}/ops.json`)).map((x) => x.name).sort(),
    bans: (await readJson(`${dir}/banned-players.json`)).map((x) => ({ name: x.name, reason: x.reason })),
    known: (await readJson(`${dir}/usercache.json`)).map((x) => x.name).sort(),
  };
}

const playerActions = {
  op: (p) => `op ${p}`,
  deop: (p) => `deop ${p}`,
  kick: (p) => `kick ${p}`,
  ban: (p, r) => `ban ${p}${r ? " " + r : ""}`,
  pardon: (p) => `pardon ${p}`,
  allow: (p) => `whitelist add ${p}`,
  disallow: (p) => `whitelist remove ${p}`,
  whitelist: (_, r) => `whitelist ${r === "on" ? "on" : "off"}`,
};

async function activity(name) {
  const known = (await readJson(`${root}/${name}/usercache.json`)).map((x) => x.name).filter(validPlayer);
  const { out } = await run("journalctl", ["-u", `minecraft@${name}.service`, "--since", "-7d", "-n", "50000", "-o", "short-unix", "--no-pager"]);
  const events = [];
  const rules = [
    [/^(\w{1,16}) joined the game$/, "join", () => "joined the game"],
    [/^(\w{1,16}) left the game$/, "leave", () => "left the game"],
    [/^(\w{1,16}) has (?:made the advancement|completed the challenge|reached the goal) \[(.+)\]$/, "advancement", (m) => m[2]],
    [/^Banned (\w{1,16}): (.*)$/, "ban", (m) => "was banned" + (m[2] && m[2] !== "Banned by an operator." ? ": " + m[2] : "")],
    [/^Unbanned (\w{1,16})$/, "pardon", () => "was unbanned"],
    [/^Kicked (\w{1,16}): (.*)$/, "kick", () => "was kicked"],
    [/^Made (\w{1,16}) a server operator$/, "op", () => "became an operator"],
    [/^Made (\w{1,16}) no longer a server operator$/, "deop", () => "is no longer an operator"],
  ];
  for (const l of out.split("\n")) {
    const m = l.match(/^(\d+)(?:\.\d+)? \S+ [^:]+: \[[\d:]+\] \[Server thread\/INFO\]: (.*)$/);
    if (!m) continue;
    const t = Number(m[1]) * 1000;
    const msg = m[2].trim().replace(/^(?:System |Player |Disguised )?[Cc]hat: /, "");
    let hit = null;
    for (const [re, type, text] of rules) {
      const r = msg.match(re);
      if (r) { hit = { t, type, player: r[1], text: text(r) }; break; }
    }
    if (!hit && !msg.startsWith("<") && !/lost connection|moved too quickly|moved wrongly|issued server command|logged in with/.test(msg)) {
      const p = known.find((k) => msg.startsWith(k + " "));
      if (p) hit = { t, type: "death", player: p, text: msg.slice(p.length + 1) };
    }
    if (hit) events.push(hit);
  }
  return events.slice(-150).reverse();
}

async function modrinth(path, opts = {}) {
  const r = await fetch(`https://api.modrinth.com/v2${path}`, { ...opts, headers: { "user-agent": agent, ...(opts.headers ?? {}) } });
  if (!r.ok) throw new Error(`modrinth: ${r.status}`);
  return r.json();
}

async function sha1(data) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-1", data))].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function levelName(name) {
  const props = await Deno.readTextFile(`${root}/${name}/server.properties`).catch(() => "");
  const level = props.match(/^level-name=(.*)$/m)?.[1]?.trim();
  return level && /^[A-Za-z0-9_ .-]+$/.test(level) && !level.includes("..") ? level : "world";
}

const kinds = {
  mod: { loader: "fabric", type: "mod", ext: ".jar", folder: async (name) => `${root}/${name}/mods` },
  datapack: { loader: "datapack", type: "datapack", ext: ".zip", folder: async (name) => `${root}/${name}/${await levelName(name)}/datapacks` },
};
const kindOf = (k) => kinds[k] ? k : "mod";
const validFile = (f, kind) => typeof f === "string" && /^[A-Za-z0-9._+-]+$/.test(f) && !f.startsWith(".") && f.endsWith(kinds[kind].ext);
const safeName = (f) => f.replace(/[^A-Za-z0-9._+-]/g, "_").replace(/^\.+/, "");

const hashCache = new Map();
const versionCache = new Map();
const projectCache = new Map();
const updateCache = new Map();

async function checkUpdates(name, kind, hashes) {
  const now = Date.now();
  const need = hashes.filter((h) => !updateCache.has(kind + h) || now - updateCache.get(kind + h).t > 600000);
  if (!need.length) return;
  try {
    const r = await modrinth("/version_files/update", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ hashes: need, algorithm: "sha1", loaders: [kinds[kind].loader], game_versions: [servers[name].version] }),
    });
    for (const h of need) {
      const v = r[h];
      const f = v ? (v.files.find((x) => x.primary) ?? v.files[0]) : null;
      updateCache.set(kind + h, { t: now, v: v ? { number: v.version_number, sha1: f?.hashes?.sha1 } : null });
    }
  } catch {}
}

async function packs(name, kind) {
  const dir = await kinds[kind].folder(name);
  const files = [];
  try {
    for await (const e of Deno.readDir(dir)) {
      if (!e.isFile || !e.name.endsWith(kinds[kind].ext)) continue;
      const st = await Deno.stat(`${dir}/${e.name}`);
      const key = `${dir}/${e.name}:${st.size}:${st.mtime?.getTime()}`;
      if (!hashCache.has(key)) hashCache.set(key, await sha1(await Deno.readFile(`${dir}/${e.name}`)));
      files.push({ file: e.name, size: st.size, hash: hashCache.get(key) });
    }
  } catch {}
  const unknown = files.map((f) => f.hash).filter((h) => !versionCache.has(h));
  if (unknown.length) {
    try {
      const found = await modrinth("/version_files", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ hashes: unknown, algorithm: "sha1" }),
      });
      for (const h of unknown) versionCache.set(h, found[h] ? { project: found[h].project_id, version: found[h].version_number } : null);
    } catch {}
  }
  const ids = [...new Set(files.map((f) => versionCache.get(f.hash)?.project).filter((p) => p && !projectCache.has(p)))];
  if (ids.length) {
    try {
      for (const p of await modrinth(`/projects?ids=${encodeURIComponent(JSON.stringify(ids))}`)) {
        projectCache.set(p.id, { title: p.title, icon: p.icon_url, slug: p.slug, type: p.project_type });
      }
    } catch {}
  }
  await checkUpdates(name, kind, files.filter((f) => versionCache.get(f.hash)).map((f) => f.hash));
  return files.map((f) => {
    const v = versionCache.get(f.hash);
    const p = v ? projectCache.get(v.project) : null;
    const u = updateCache.get(kind + f.hash)?.v;
    return {
      file: f.file,
      size: f.size,
      project: v?.project ?? null,
      version: v?.version ?? null,
      title: p?.title ?? null,
      icon: p?.icon ?? null,
      slug: p?.slug ?? null,
      type: p?.type ?? kinds[kind].type,
      update: u && u.sha1 && u.sha1 !== f.hash ? u.number : null,
    };
  }).sort((a, b) => (a.title ?? a.file).localeCompare(b.title ?? b.file));
}

async function search(name, q, kind) {
  const facets = [[`project_type:${kinds[kind].type}`], [`versions:${servers[name].version}`]];
  if (kind === "mod") facets.push(["categories:fabric"]);
  const r = await modrinth(`/search?limit=20&query=${encodeURIComponent(q)}&facets=${encodeURIComponent(JSON.stringify(facets))}`);
  return r.hits.map((h) => ({ project: h.project_id, title: h.title, description: h.description, icon: h.icon_url, downloads: h.downloads, slug: h.slug, type: h.project_type }));
}

async function install(name, project, installed, kind, done = []) {
  if (done.some((d) => d.project === project)) return done;
  const q = `loaders=${encodeURIComponent(JSON.stringify([kinds[kind].loader]))}&game_versions=${encodeURIComponent(JSON.stringify([servers[name].version]))}`;
  const versions = await modrinth(`/project/${encodeURIComponent(project)}/version?${q}`);
  if (!versions.length) throw new Error(`no ${servers[name].version} ${kinds[kind].loader} version available`);
  const v = versions[0];
  const file = v.files.find((f) => f.primary) ?? v.files[0];
  const target = safeName(file.filename);
  if (!validFile(target, kind) || !file.url.startsWith("https://cdn.modrinth.com/")) throw new Error("unexpected file from modrinth");
  const dir = await kinds[kind].folder(name);
  await Deno.mkdir(dir, { recursive: true });
  const old = installed.filter((m) => m.project === project);
  if (!old.some((m) => m.file === target)) {
    const r = await fetch(file.url, { headers: { "user-agent": agent } });
    if (!r.ok) throw new Error(`download failed: ${r.status}`);
    const data = new Uint8Array(await r.arrayBuffer());
    if (await sha1(data) !== file.hashes.sha1) throw new Error("download corrupted");
    await Deno.writeFile(`${dir}/${target}.part`, data);
    await Deno.rename(`${dir}/${target}.part`, `${dir}/${target}`);
    for (const m of old) await Deno.remove(`${dir}/${m.file}`).catch(() => {});
  }
  done.push({ project, version: v.version_number, file: target });
  for (const d of v.dependencies ?? []) {
    if (d.dependency_type !== "required" || !d.project_id) continue;
    if (installed.some((m) => m.project === d.project_id)) continue;
    await install(name, d.project_id, installed, kind, done);
  }
  return done;
}

const lagCache = {};

async function lag(name) {
  const c = lagCache[name];
  if (c && Date.now() - c.t < 15000) return c.v;
  const { out } = await run("journalctl", ["-u", `minecraft@${name}.service`, "--since", "-10min", "-o", "cat", "--no-pager", "-g", "Can't keep up"]);
  const behind = [...out.matchAll(/Running (\d+)ms or (\d+) ticks behind/g)].map((m) => Number(m[1])).filter((ms) => ms < 15000);
  const v = behind.length ? { count: behind.length, max: Math.max(...behind) } : null;
  lagCache[name] = { t: Date.now(), v };
  return v;
}

async function crashes(name) {
  const dir = `${root}/${name}/crash-reports`;
  const out = [];
  try {
    for await (const e of Deno.readDir(dir)) {
      if (!e.isFile || !/^crash-[\w.+-]+\.txt$/.test(e.name)) continue;
      const st = await Deno.stat(`${dir}/${e.name}`);
      out.push({ file: e.name, time: st.mtime?.getTime() ?? 0, size: st.size });
    }
  } catch {}
  out.sort((a, b) => b.time - a.time);
  const top = out.slice(0, 15);
  for (const c of top) Object.assign(c, analyze(await Deno.readTextFile(`${dir}/${c.file}`).catch(() => "")));
  const s = await show(`minecraft@${name}.service`, ["ActiveState", "Result", "InactiveEnterTimestamp"]);
  if (s.ActiveState === "failed") {
    const { out: log } = await run("journalctl", ["-u", `minecraft@${name}.service`, "-n", "120", "-o", "cat", "--no-pager"]);
    top.unshift({ file: null, time: stamp(s.InactiveEnterTimestamp) ?? Date.now(), startup: true, ...analyze(log), text: log });
  }
  return top;
}

function analyze(textIn) {
  const t = textIn.slice(0, 600000);
  const description = t.match(/^Description: (.*)$/m)?.[1]?.trim() ?? null;
  let error = null;
  const d = t.indexOf("Description:");
  if (d >= 0) error = t.slice(d).split("\n").slice(1).map((l) => l.trim()).find((l) => l && !l.startsWith("at ")) ?? null;
  if (!error) error = t.split("\n").find((l) => /\/ERROR\]|Exception|Incompatible mods|requires|Could not/.test(l))?.trim() ?? null;
  const suspects = new Set();
  const line = t.match(/^Suspected Mods?: (.*)$/m)?.[1];
  if (line && !/^none$/i.test(line.trim())) for (const m of line.split(",")) suspects.add(m.trim());
  for (const m of t.matchAll(/(?:from mod|Mixin apply for mod|mod) '?([a-z0-9_-]{2,64})'?(?: \(| failed| requires| is incompatible| version)/g)) suspects.add(m[1]);
  for (const m of t.matchAll(/^\s*-\s*(?:Mod|Install|Replace|Remove) '([^']+)' \(([a-z0-9_-]+)\)/gm)) suspects.add(`${m[1]} (${m[2]})`);
  ["minecraft", "java", "fabricloader", "mod", "fabric"].forEach((x) => suspects.delete(x));
  for (const x of [...suspects]) if ([...suspects].some((y) => y !== x && y.endsWith(`(${x})`))) suspects.delete(x);
  return { description, error, suspects: [...suspects].slice(0, 8), text: textIn.slice(0, 200000) };
}

async function profile(name, player) {
  const { out } = await run("journalctl", ["-u", `minecraft@${name}.service`, "-o", "short-unix", "--no-pager", "-g", `${player}|Stopping server|Starting minecraft server`]);
  const now = Date.now();
  const sessions = [];
  const deaths = [];
  const advancements = [];
  let open = null;
  let first = null;
  let last = null;
  let kicks = 0;
  const close = (t) => { if (open !== null) { sessions.push([open, t]); open = null; } };
  for (const l of out.split("\n")) {
    const m = l.match(/^(\d+)(?:\.\d+)? \S+ [^:]+: \[[\d:]+\] \[Server thread\/INFO\]: (.*)$/);
    if (!m) continue;
    const t = Number(m[1]) * 1000;
    const msg = m[2].trim().replace(/^(?:System |Player |Disguised )?[Cc]hat: /, "");
    if (msg === `${player} joined the game`) { close(t); open = t; first ??= t; last = t; continue; }
    if (msg === `${player} left the game`) { close(t); last = t; continue; }
    if (/^Stopping server|^Starting minecraft server/.test(msg)) { close(t); continue; }
    const adv = msg.match(new RegExp(`^${player} has (?:made the advancement|completed the challenge|reached the goal) \\[(.+)\\]$`));
    if (adv) { advancements.push({ t, text: adv[1] }); continue; }
    if (msg.startsWith(`Kicked ${player}:`)) { kicks++; continue; }
    if (msg.startsWith(player + " ") && !msg.startsWith("<") && !/lost connection|moved too quickly|moved wrongly|issued server command|logged in with|joined the game|left the game/.test(msg)) {
      deaths.push({ t, text: msg.slice(player.length + 1) });
    }
  }
  const online = open !== null;
  if (online) { sessions.push([open, now]); last = now; }
  const playtime = sessions.reduce((a, [s, e]) => a + Math.max(0, e - s), 0);
  return {
    player,
    online,
    playtime,
    sessions: sessions.length,
    longest: sessions.reduce((a, [s, e]) => Math.max(a, e - s), 0),
    first,
    last,
    kicks,
    deaths: deaths.length,
    recentDeaths: deaths.slice(-6).reverse(),
    advancements: advancements.length,
    recentAdvancements: advancements.slice(-12).reverse(),
    achieved: await playerAdvancements(name).then((a) => a[player] ?? {}),
    stats: (await gameStats(name))[player] ?? null,
    total: (await worlds(name)) ? (await gameStats(name, true))[player] ?? null : null,
  };
}

const short = (k) => k.replace(/^minecraft:/, "");
const sum = (o) => Object.values(o ?? {}).reduce((a, b) => a + (Number(b) || 0), 0);
const top = (o, n) => Object.entries(o ?? {}).sort((a, b) => b[1] - a[1]).slice(0, n).map(([k, v]) => [short(k), v]);
const travelModes = {
  "on foot": ["walk_one_cm", "sprint_one_cm", "crouch_one_cm", "climb_one_cm"],
  swimming: ["swim_one_cm", "walk_on_water_one_cm", "walk_under_water_one_cm"],
  elytra: ["aviate_one_cm"],
  flying: ["fly_one_cm"],
  falling: ["fall_one_cm"],
};

function condense(raw) {
  const s = raw?.stats ?? {};
  const c = Object.fromEntries(Object.entries(s["minecraft:custom"] ?? {}).map(([k, v]) => [short(k), Number(v) || 0]));
  const cm = Object.entries(c).filter(([k]) => k.endsWith("_one_cm"));
  const grouped = new Set(Object.values(travelModes).flat());
  const travel = Object.entries(travelModes).map(([k, keys]) => [k, keys.reduce((a, x) => a + (c[x] ?? 0), 0)]);
  travel.push(["riding", cm.filter(([k]) => !grouped.has(k)).reduce((a, [, v]) => a + v, 0)]);
  return {
    playtime: (c.play_time ?? c.play_one_minute ?? 0) * 50,
    deaths: c.deaths ?? 0,
    mobKills: c.mob_kills ?? 0,
    playerKills: c.player_kills ?? 0,
    damageDealt: (c.damage_dealt ?? 0) / 10,
    damageTaken: (c.damage_taken ?? 0) / 10,
    jumps: c.jump ?? 0,
    distance: cm.reduce((a, [, v]) => a + v, 0),
    sinceDeath: (c.time_since_death ?? 0) * 50,
    sleeps: c.sleep_in_bed ?? 0,
    fish: c.fish_caught ?? 0,
    bred: c.animals_bred ?? 0,
    trades: c.traded_with_villager ?? 0,
    enchants: c.enchant_item ?? 0,
    mined: sum(s["minecraft:mined"]),
    crafted: sum(s["minecraft:crafted"]),
    broken: sum(s["minecraft:broken"]),
    travel: travel.filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]),
    topMined: top(s["minecraft:mined"], 6),
    topKilled: top(s["minecraft:killed"], 6),
    killedBy: top(s["minecraft:killed_by"], 6),
    topCrafted: top(s["minecraft:crafted"], 6),
  };
}

async function statsDirs(dir, want = "stats", depth = 0) {
  const found = [];
  try {
    for await (const e of Deno.readDir(dir)) {
      if (!e.isDirectory || e.name.startsWith(".")) continue;
      if (e.name === want) found.push(`${dir}/${want}`);
      else if (depth < 2 && !["region", "entities", "poi", "data", "datapacks", "dimensions", "DIM-1", "DIM1"].includes(e.name)) found.push(...await statsDirs(`${dir}/${e.name}`, want, depth + 1));
    }
  } catch {}
  return found;
}

const namesFile = "/var/lib/mcpanel/names.json";
let uuidNames = {};
try { uuidNames = JSON.parse(await Deno.readTextFile(namesFile)); } catch {}

async function lookupName(uuid) {
  if (uuid in uuidNames) return uuidNames[uuid];
  let name = null;
  try {
    const r = await fetch(`https://sessionserver.mojang.com/session/minecraft/profile/${uuid.replace(/-/g, "")}`, { headers: { "user-agent": agent } });
    if (r.status === 200) name = (await r.json()).name ?? null;
    else if (r.status !== 204 && r.status !== 404) return null;
  } catch { return null; }
  uuidNames[uuid] = validPlayer(name) ? name : null;
  await Deno.writeTextFile(namesFile, JSON.stringify(uuidNames)).catch(() => {});
  return uuidNames[uuid];
}

async function rawStats(dirs, byUuid) {
  const out = {};
  for (const dir of dirs) {
    try {
      for await (const e of Deno.readDir(dir)) {
        if (!e.isFile || !e.name.endsWith(".json")) continue;
        const uuid = e.name.slice(0, -5).toLowerCase();
        if (!/^[0-9a-f-]{32,36}$/.test(uuid)) continue;
        const player = byUuid[uuid] ?? await lookupName(uuid);
        if (!validPlayer(player) || out[player]) continue;
        try { out[player] = JSON.parse(await Deno.readTextFile(`${dir}/${e.name}`)); } catch {}
      }
    } catch {}
  }
  return out;
}

function mergeRaw(a, b) {
  const s = structuredClone(a?.stats ?? {});
  for (const [cat, vals] of Object.entries(b?.stats ?? {})) {
    s[cat] ??= {};
    for (const [k, v] of Object.entries(vals)) {
      if (/time_since/.test(k)) continue;
      s[cat][k] = (Number(s[cat][k]) || 0) + (Number(v) || 0);
    }
  }
  return { stats: s };
}

async function gameStats(name, everything = false) {
  const byUuid = await uuidMap(name);
  const raw = await rawStats(await statsDirs(`${root}/${name}/${await levelName(name)}`), byUuid);
  if (everything) {
    const archive = `${root}/${name}/.stats`;
    const old = [];
    try { for await (const e of Deno.readDir(archive)) if (e.isDirectory) old.push(`${archive}/${e.name}`); } catch {}
    for (const dir of old) {
      for (const [player, r] of Object.entries(await rawStats([dir], byUuid))) raw[player] = raw[player] ? mergeRaw(raw[player], r) : mergeRaw({ stats: {} }, r);
    }
  }
  return Object.fromEntries(Object.entries(raw).map(([k, v]) => [k, condense(v)]));
}

async function worlds(name) {
  let n = 0;
  try { for await (const e of Deno.readDir(`${root}/${name}/.stats`)) if (e.isDirectory) n++; } catch {}
  return n;
}

async function uuidMap(name) {
  return Object.fromEntries((await readJson(`${root}/${name}/usercache.json`)).map((u) => [String(u.uuid).toLowerCase(), u.name]));
}

const advList = JSON.parse(await Deno.readTextFile(Deno.args[2]).catch(() => "[]"));
const advIds = new Set(advList.map((a) => a.id));
const advTime = (v) => Math.max(0, ...Object.values(v?.criteria ?? {}).map((s) => Date.parse(String(s).replace(" ", "T").replace(/ ([+-]\d\d)(\d\d)$/, "$1:$2")) || 0)) || null;

async function playerAdvancements(name) {
  const raw = await rawStats(await statsDirs(`${root}/${name}/${await levelName(name)}`, "advancements"), await uuidMap(name));
  return Object.fromEntries(Object.entries(raw).map(([p, r]) => [p, Object.fromEntries(Object.entries(r ?? {}).filter(([k, v]) => advIds.has(k) && v?.done).map(([k, v]) => [k, advTime(v)]))]));
}

async function leaderboard(name, everything = false) {
  const all = await gameStats(name, everything);
  const adv = await playerAdvancements(name);
  return Object.entries(all).map(([player, s]) => ({ player, ...Object.fromEntries(Object.entries(s).filter(([, v]) => typeof v === "number")), advancements: Object.keys(adv[player] ?? {}).length }));
}

const packDir = "/var/lib/mcpanel/packs";
const packMeta = "/var/lib/mcpanel/packmeta";
const propEscape = (v) => String(v).replace(/\\/g, "\\\\").replace(/:/g, "\\:").replace(/=/g, "\\=").replace(/\n/g, "\\n");
const propUnescape = (v) => v.replace(/\\(.)/g, (_, c) => c === "n" ? "\n" : c);

function getProp(txt, key) {
  const l = txt.split("\n").find((x) => x.startsWith(key + "="));
  return l == null ? null : propUnescape(l.slice(key.length + 1));
}

function setProps(txt, values) {
  const lines = txt.split("\n");
  if (lines[lines.length - 1] === "") lines.pop();
  for (const [k, v] of Object.entries(values)) {
    const line = `${k}=${propEscape(v)}`;
    const i = lines.findIndex((x) => x.startsWith(k + "="));
    if (i >= 0) lines[i] = line;
    else lines.push(line);
  }
  return lines.join("\n") + "\n";
}

async function applyProps(name, values) {
  const file = `${root}/${name}/server.properties`;
  const up = (await show(`minecraft@${name}.service`, ["ActiveState"])).ActiveState === "active";
  if (up) {
    const stop = await run("systemctl", ["stop", `minecraft@${name}.service`]);
    if (!stop.ok) throw new Error(stop.err.trim() || "could not stop the server");
  }
  const txt = await Deno.readTextFile(file).catch(() => "");
  await Deno.writeTextFile(file, setProps(txt, values));
  if (up) await run("systemctl", ["start", "--no-block", `minecraft@${name}.service`]);
  return up;
}

async function packInfo(name) {
  const txt = await Deno.readTextFile(`${root}/${name}/server.properties`).catch(() => "");
  const url = getProp(txt, "resource-pack") ?? "";
  let prompt = getProp(txt, "resource-pack-prompt") ?? "";
  try { const j = JSON.parse(prompt); prompt = typeof j === "string" ? j : j?.text ?? prompt; } catch {}
  const meta = await Deno.readTextFile(`${packMeta}/${name}.json`).then(JSON.parse).catch(() => null);
  return {
    url,
    sha1: getProp(txt, "resource-pack-sha1") ?? "",
    required: getProp(txt, "require-resource-pack") === "true",
    prompt,
    meta: meta && url.endsWith("/" + meta.file) ? meta : null,
    base: packUrl,
  };
}

async function storePack(name, data, meta) {
  if (data.length < 4 || data[0] !== 0x50 || data[1] !== 0x4b) throw new Error("not a zip file");
  if (data.length > 250 * 1048576) throw new Error("pack is larger than 250 MB");
  const hash = await sha1(data);
  await Deno.mkdir(packDir, { recursive: true });
  const file = `${name}${hash}.zip`;
  await Deno.writeFile(`${packDir}/${file}.part`, data);
  await Deno.rename(`${packDir}/${file}.part`, `${packDir}/${file}`);
  await Deno.mkdir(packMeta, { recursive: true });
  await Deno.writeTextFile(`${packMeta}/${name}.json`, JSON.stringify({ ...meta, file, size: data.length, sha1: hash }));
  const restarted = await applyProps(name, { "resource-pack": `${packUrl}/${file}`, "resource-pack-sha1": hash });
  for await (const e of Deno.readDir(packDir)) {
    if (e.isFile && e.name !== file && e.name.length === name.length + 44 && e.name.startsWith(name) && /^[0-9a-f]{40}\.zip$/.test(e.name.slice(name.length))) {
      await Deno.remove(`${packDir}/${e.name}`).catch(() => {});
    }
  }
  return { file, sha1: hash, restarted };
}

async function packSearch(name, q) {
  const facets = [["project_type:resourcepack"], [`versions:${servers[name].version}`]];
  const r = await modrinth(`/search?limit=20&query=${encodeURIComponent(q)}&facets=${encodeURIComponent(JSON.stringify(facets))}`);
  return r.hits.map((h) => ({ project: h.project_id, title: h.title, description: h.description, icon: h.icon_url, downloads: h.downloads, slug: h.slug }));
}

async function packInstall(name, project) {
  const q = `loaders=${encodeURIComponent('["minecraft"]')}&game_versions=${encodeURIComponent(JSON.stringify([servers[name].version]))}`;
  const versions = await modrinth(`/project/${encodeURIComponent(project)}/version?${q}`);
  if (!versions.length) throw new Error(`no ${servers[name].version} version of this pack`);
  const v = versions[0];
  const f = v.files.find((x) => x.primary) ?? v.files[0];
  if (!f.url.startsWith("https://cdn.modrinth.com/")) throw new Error("unexpected file from modrinth");
  const r = await fetch(f.url, { headers: { "user-agent": agent } });
  if (!r.ok) throw new Error(`download failed: ${r.status}`);
  const data = new Uint8Array(await r.arrayBuffer());
  if (await sha1(data) !== f.hashes.sha1) throw new Error("download corrupted");
  const p = await modrinth(`/project/${encodeURIComponent(project)}`).catch(() => ({}));
  return storePack(name, data, { title: p.title ?? f.filename, icon: p.icon_url ?? null, project, version: v.version_number, original: f.filename });
}

let history = {};
try { history = JSON.parse(await Deno.readTextFile(histFile)); } catch {}

function nbt(buf) {
  const v = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  let o = 0;
  const str = () => { const n = v.getUint16(o); o += 2; const s = dec.decode(buf.subarray(o, o + n)); o += n; return s; };
  const int = () => { const x = v.getInt32(o); o += 4; return x; };
  const read = (t) => {
    switch (t) {
      case 1: return v.getInt8(o++);
      case 2: { const x = v.getInt16(o); o += 2; return x; }
      case 3: return int();
      case 4: { const x = v.getBigInt64(o); o += 8; return x; }
      case 5: { const x = v.getFloat32(o); o += 4; return x; }
      case 6: { const x = v.getFloat64(o); o += 8; return x; }
      case 7: { o += int(); return null; }
      case 8: return str();
      case 9: { const et = v.getInt8(o++); const n = int(); const a = []; for (let i = 0; i < n; i++) a.push(read(et)); return a; }
      case 10: { const r = {}; const types = {}; Object.defineProperty(r, "$types", { value: types }); for (;;) { const tt = v.getInt8(o++); if (tt === 0) return r; const k = str(); types[k] = tt; r[k] = read(tt); } }
      case 11: { const n = int(); if (n === 3) { const a = [int(), int(), int()]; return a; } o += n * 4; return null; }
      case 12: { o += int() * 8; return null; }
    }
    throw new Error("bad nbt");
  };
  const t = v.getInt8(o++);
  str();
  return read(t);
}

async function readNbt(path) {
  const raw = await Deno.readFile(path);
  const data = raw[0] === 0x1f && raw[1] === 0x8b ? new Uint8Array(await new Response(new Blob([raw]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer()) : raw;
  return nbt(data);
}

function find(obj, ...keys) {
  const want = keys.map((k) => k.toLowerCase().replace(/_/g, ""));
  const queue = [obj];
  while (queue.length) {
    const x = queue.shift();
    if (!x || typeof x !== "object") continue;
    if (Array.isArray(x)) { for (const y of x) if (y && typeof y === "object") queue.push(y); continue; }
    for (const [k, val] of Object.entries(x)) if (want.includes(k.toLowerCase().replace(/_/g, ""))) return val;
    for (const val of Object.values(x)) if (val && typeof val === "object") queue.push(val);
  }
  return undefined;
}

const worldActions = ["reset", "nether", "end", "import", "delete"];
const levelTypes = ["minecraft:normal", "minecraft:flat", "minecraft:large_biomes", "minecraft:amplified"];

async function walkSize(dir, rel, sizes) {
  try {
    for await (const e of Deno.readDir(dir)) {
      const p = `${dir}/${e.name}`;
      const r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory) await walkSize(p, r, sizes);
      else if (e.isFile) {
        const size = (await Deno.stat(p).catch(() => null))?.size ?? 0;
        const kind = /(^|\/)(DIM-1|the_nether)(\/|$)/.test(r) ? "nether" : /(^|\/)(DIM1|the_end)(\/|$)/.test(r) ? "end" : /(^|\/)(players|playerdata|stats|advancements)(\/|$)/.test(r) ? "players" : /(^|\/)datapacks(\/|$)/.test(r) ? "datapacks" : /(^|\/)(region|entities|poi|overworld)(\/|$)/.test(r) ? "overworld" : "other";
        sizes[kind] = (sizes[kind] ?? 0) + size;
      }
    }
  } catch {}
}

async function worldJobs(name) {
  const jobs = await Promise.all(worldActions.map(async (a) => ({ action: a, ...await show(`minecraft-world@${name}:${a}.service`, ["ActiveState", "Result", "InactiveEnterTimestamp"]) })));
  const busy = jobs.find((j) => ["active", "activating", "deactivating"].includes(j.ActiveState))?.action ?? null;
  const done = jobs.filter((j) => stamp(j.InactiveEnterTimestamp)).sort((a, b) => stamp(b.InactiveEnterTimestamp) - stamp(a.InactiveEnterTimestamp))[0];
  let last = null;
  if (done) {
    last = { action: done.action, ok: done.Result === "success", t: stamp(done.InactiveEnterTimestamp) };
    if (!last.ok) last.message = (await run("journalctl", ["-u", `minecraft-world@${name}:${done.action}.service`, "-n", "1", "-o", "cat", "--no-pager"])).out.trim();
  }
  return { busy, last };
}

async function worldInfo(name) {
  const level = await levelName(name);
  const dir = `${root}/${name}/${level}`;
  const props = await Deno.readTextFile(`${root}/${name}/server.properties`).catch(() => "");
  const sources = [];
  sources.push(await readNbt(`${dir}/level.dat`).catch(() => null));
  const extra = [];
  for (const sub of ["data", "data/minecraft"]) {
    try {
      for await (const e of Deno.readDir(`${dir}/${sub}`)) {
        if (!e.isFile || !e.name.endsWith(".dat") || /^(map_|random_seq|raids|scoreboard|idcounts|command_storage|chunks|structure)/i.test(e.name)) continue;
        const p = `${dir}/${sub}/${e.name}`;
        if (((await Deno.stat(p).catch(() => null))?.size ?? Infinity) > 262144) continue;
        extra.push(p);
      }
    } catch {}
  }
  const rank = (p) => /world_?gen|game_?rule|level|spawn|clock|time|weather/i.test(p) ? 0 : 1;
  for (const p of extra.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))) sources.push(await readNbt(p).catch(() => null));
  const found = sources.filter(Boolean);
  const find_ = (...keys) => { for (const s of found) { const v = find(s, ...keys); if (v !== undefined) return v; } return undefined; };
  const seed = find_("seed", "RandomSeed");
  let difficulty = find_("Difficulty");
  if (difficulty && typeof difficulty === "object") difficulty = difficulty.difficulty ?? null;
  if (typeof difficulty === "number") difficulty = ["peaceful", "easy", "normal", "hard"][difficulty] ?? null;
  const hardcore = find_("hardcore");
  const clocks = await readNbt(`${dir}/data/minecraft/world_clocks.dat`).catch(() => null);
  const dayTime = find_("DayTime") ?? clocks?.data?.["minecraft:overworld"]?.total_ticks;
  const sx = find_("SpawnX");
  const spawnObj = find_("spawn");
  const spawn = sx !== undefined ? [sx, find_("SpawnY"), find_("SpawnZ")] : Array.isArray(spawnObj?.pos) ? spawnObj.pos : null;
  const rules = find_("GameRules") ?? (await readNbt(`${dir}/data/minecraft/game_rules.dat`).catch(() => null))?.data;
  const sizes = {};
  await walkSize(dir, "", sizes);
  const exists = Object.values(sizes).reduce((a, b) => a + b, 0) > 0;
  return {
    level,
    exists,
    name: find_("LevelName") ?? null,
    version: find_("Version")?.Name ?? null,
    seed: seed !== undefined && seed !== null ? String(seed) : null,
    difficulty: typeof difficulty === "string" ? difficulty.replace(/^minecraft:/, "") : getProp(props, "difficulty"),
    hardcore: hardcore === undefined ? getProp(props, "hardcore") === "true" : !!hardcore,
    day: dayTime !== undefined ? Math.floor(Number(dayTime) / 24000) + 1 : null,
    lastPlayed: (() => { const l = find_("LastPlayed"); return l !== undefined ? Number(l) : null; })(),
    spawn,
    rules: rules && typeof rules === "object" ? Object.fromEntries(Object.entries(rules).map(([k, val]) => [k.replace(/^minecraft:/, ""), rules.$types?.[k] === 1 ? !!val : typeof val === "bigint" ? Number(val) : val])) : null,
    sizes,
    seedProp: getProp(props, "level-seed") ?? "",
    typeProp: getProp(props, "level-type") ?? "minecraft:normal",
    ...await worldJobs(name),
  };
}

async function startWorld(name, action) {
  if ((await worldJobs(name)).busy) throw new Error("another world task is running");
  const r = await run("systemctl", ["start", "--no-block", `minecraft-world@${name}:${action}.service`]);
  if (!r.ok) throw new Error(r.err.trim() || "could not start the task");
}

const iconRoot = "/var/lib/mcpanel/icons";
const validIcon = (id) => typeof id === "string" && /^[0-9a-f]{40}$/.test(id);

function checkPng(data) {
  const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (data.length < 24 || sig.some((b, i) => data[i] !== b)) throw new Error("not a png file");
  if (data.length > 1048576) throw new Error("icon is larger than 1 MB");
  const v = new DataView(data.buffer, data.byteOffset);
  if (v.getUint32(16) !== 64 || v.getUint32(20) !== 64) throw new Error("icon must be 64×64");
}

async function storeIcon(name, data) {
  checkPng(data);
  const id = await sha1(data);
  const dir = `${iconRoot}/${name}`;
  await Deno.mkdir(dir, { recursive: true });
  await Deno.writeFile(`${dir}/${id}.png`, data);
  return id;
}

async function useIcon(name, id) {
  const file = `${root}/${name}/server-icon.png`;
  if (id === null) { await Deno.remove(file).catch(() => {}); return; }
  const data = await Deno.readFile(`${iconRoot}/${name}/${id}.png`);
  await Deno.writeFile(`${file}.part`, data);
  await Deno.chown(`${file}.part`, null, (await Deno.stat(`${root}/${name}`)).gid);
  await Deno.chmod(`${file}.part`, 0o660);
  await Deno.rename(`${file}.part`, file);
}

async function icons(name) {
  const current = await Deno.readFile(`${root}/${name}/server-icon.png`).catch(() => null);
  let active = null;
  if (current) {
    try { active = await storeIcon(name, current); } catch { active = await sha1(current); }
  }
  let live;
  if ((await show(`minecraft@${name}.service`, ["ActiveState"])).ActiveState === "active") {
    const fav = (await ping(servers[name].port).catch(() => null))?.favicon;
    live = typeof fav === "string" && fav.includes(",") ? await sha1(Uint8Array.from(atob(fav.split(",")[1].replace(/\s/g, "")), (c) => c.charCodeAt(0))) : null;
  }
  const list = [];
  try {
    for await (const e of Deno.readDir(`${iconRoot}/${name}`)) {
      if (!e.isFile || !e.name.endsWith(".png") || !validIcon(e.name.slice(0, -4))) continue;
      list.push({ id: e.name.slice(0, -4), time: (await Deno.stat(`${iconRoot}/${name}/${e.name}`)).mtime?.getTime() ?? 0 });
    }
  } catch {}
  return { active, live, list: list.sort((a, b) => b.time - a.time) };
}

const pngResponse = (data) => new Response(data, { headers: { "content-type": "image/png", "cache-control": "no-cache" } });

async function sample() {
  for (const name of names) {
    const s = await status(name, samplePrev).catch(() => null);
    if (!s) continue;
    const list = history[name] ??= [];
    list.push([Date.now(), s.players?.online ?? 0, s.used, s.cpu]);
    if (list.length > 1440) list.splice(0, list.length - 1440);
  }
  await Deno.writeTextFile(`${histFile}.tmp`, JSON.stringify(history)).then(() => Deno.rename(`${histFile}.tmp`, histFile)).catch(() => {});
}

await sample();
setInterval(sample, 60000);

const text = (body, status = 200) => new Response(body, { status });

const pageDir = Deno.args[0];
const pageVersion = pageDir.split("/").pop().slice(0, 8);
const page = (await Deno.readTextFile(`${pageDir}/index.html`)).replaceAll("VERSION", pageVersion);
const dashboardPage = (await Deno.readTextFile(`${pageDir}/dashboard.html`)).replaceAll("VERSION", pageVersion);
const html = (body) => new Response(body, { headers: { "content-type": "text/html; charset=utf-8" } });

async function route(req) {
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
  if (url.pathname === "/") return new Response(null, { status: 302, headers: { location: "/dashboard" } });
  if (/^\/dashboard\/?$/.test(url.pathname)) return html(dashboardPage);
  const tabs = url.pathname.match(/^\/([a-z0-9]{1,16})(\/(players|activity|mods(\/(datapacks|resourcepack))?|world|stats|tasks|settings))?\/?$/);
  if (tabs && validName(tabs[1])) return html(page);
  if (parts[0] !== "api") return text("not found", 404);
  if (parts[1] === "servers" && !parts[2] && req.method === "GET") {
    return Response.json(await Promise.all([...names].map((n) => status(n))));
  }
  if (parts[1] === "servers" && !parts[2] && req.method === "POST") return Response.json(await createServer(await req.json()));
  if (parts[1] === "versions" && req.method === "GET") return Response.json(await versionList(url.searchParams.get("type") === "fabric" ? "fabric" : "vanilla"));
  if (parts[1] === "ports" && req.method === "GET") return Response.json({ from: portFrom, to: portTo, used: Object.values(servers).map((c) => c.port) });
  const name = parts[1];
  if (!names.has(name)) return text("unknown server", 404);
  if (!parts[2] && req.method === "DELETE") {
    await startWorld(name, "delete");
    return text("ok");
  }
  if (parts[2] === "config" && req.method === "PUT") return Response.json(await updateServer(name, await req.json()));
  const action = parts[2];
  const sub = parts[3];
  const props = `${root}/${name}/server.properties`;
  const running = async () => (await show(`minecraft@${name}.service`, ["ActiveState"])).ActiveState === "active";
  const kind = kindOf(url.searchParams.get("kind"));
  if (req.method === "GET") {
    if (action === "console") return logs(name, req);
    if (action === "tasks") return Response.json(await tasks(name));
    if (action === "history") return Response.json(history[name] ?? []);
    if (action === "players") return Response.json(await playerData(name));
    if (action === "activity") return Response.json(await activity(name));
    if (action === "leaderboard") return Response.json(await leaderboard(name, url.searchParams.has("all")));
    if (action === "icons") return Response.json(await icons(name));
    if (action === "world" && !sub) return Response.json(await worldInfo(name));
    if (action === "icon" && sub === "current") {
      const data = await Deno.readFile(`${root}/${name}/server-icon.png`).catch(() => null);
      return data ? pngResponse(data) : text("no icon", 404);
    }
    if (action === "icon" && validIcon(sub)) {
      const data = await Deno.readFile(`${iconRoot}/${name}/${sub}.png`).catch(() => null);
      return data ? pngResponse(data) : text("icon not found", 404);
    }
    if (action === "mods" && !sub) return Response.json(await packs(name, kind));
    if (action === "crashes") return Response.json(await crashes(name));
    if (action === "pack" && !sub) return Response.json(await packInfo(name));
    if (action === "pack" && sub === "search") return Response.json(await packSearch(name, url.searchParams.get("q") ?? ""));
    if (action === "profile" && validPlayer(sub)) return Response.json(await profile(name, sub));
    if (action === "mods" && sub === "search") return Response.json(await search(name, url.searchParams.get("q") ?? "", kind));
    if (action === "backups" && !sub) return Response.json(await backups(name));
    if (action === "backups" && validBackup(sub)) {
      try {
        const f = await Deno.open(`${root}/backups/${name}/${sub}`);
        return new Response(f.readable, { headers: { "content-type": "application/gzip", "content-disposition": `attachment; filename="${name}${sub}"` } });
      } catch {
        return text("backup not found", 404);
      }
    }
    if (action === "properties") {
      try { return text(await Deno.readTextFile(props)); } catch { return text("no server.properties yet, start the server once", 404); }
    }
    return text("not found", 404);
  }
  if (req.method === "PUT" && action === "properties") {
    const body = await req.text();
    if (body.length > 65536) return text("too large", 413);
    const content = body.endsWith("\n") ? body : body + "\n";
    if (url.searchParams.has("apply") && await running()) {
      const stop = await run("systemctl", ["stop", `minecraft@${name}.service`]);
      if (!stop.ok) return text(stop.err.trim() || "could not stop the server", 500);
      await Deno.writeTextFile(props, content);
      await run("systemctl", ["start", "--no-block", `minecraft@${name}.service`]);
      return text("restarting");
    }
    await Deno.writeTextFile(props, content);
    return text("ok");
  }
  if (req.method === "DELETE" && action === "pack") {
    await applyProps(name, { "resource-pack": "", "resource-pack-sha1": "", "require-resource-pack": "false", "resource-pack-prompt": "" });
    await Deno.remove(`${packMeta}/${name}.json`).catch(() => {});
    try { for await (const e of Deno.readDir(packDir)) if (e.isFile && e.name.length === name.length + 44 && e.name.startsWith(name) && /^[0-9a-f]{40}\.zip$/.test(e.name.slice(name.length))) await Deno.remove(`${packDir}/${e.name}`).catch(() => {}); } catch {}
    return text("ok");
  }
  if (req.method === "DELETE" && action === "icon") {
    if (sub === undefined) { await useIcon(name, null); return text("ok"); }
    if (!validIcon(sub)) return text("invalid icon", 400);
    if ((await icons(name)).active === sub) await useIcon(name, null);
    await Deno.remove(`${iconRoot}/${name}/${sub}.png`).catch(() => {});
    return text("ok");
  }
  if (req.method === "DELETE" && action === "mods") {
    if (!validFile(sub, kind)) return text("invalid file", 400);
    try { await Deno.remove(`${await kinds[kind].folder(name)}/${sub}`); } catch { return text("file not found", 404); }
    return text("ok");
  }
  if (req.method !== "POST") return text("method not allowed", 405);
  const systemctl = async (verb, unit) => {
    const r = await run("systemctl", [verb, "--no-block", unit]);
    return r.ok ? text("ok") : text(r.err.trim() || "failed", 500);
  };
  if (["start", "stop", "restart"].includes(action) && !sub) return systemctl(action, `minecraft@${name}.service`);
  if (action === "backup") return systemctl("start", `minecraft-backup@${name}.service`);
  if (action === "restore") {
    const { file } = await req.json();
    if (!validBackup(file)) return text("invalid backup", 400);
    try { await Deno.stat(`${root}/backups/${name}/${file}`); } catch { return text("backup not found", 404); }
    return systemctl("start", `minecraft-restore@${name}:${file}.service`);
  }
  if (action === "restart" && sub === "countdown") {
    if (!await running()) return text("server is not running", 409);
    return systemctl("start", `minecraft-restart@${name}.service`);
  }
  if (action === "restart" && sub === "cancel") {
    const r = await systemctl("stop", `minecraft-restart@${name}.service`);
    if (await running()) await command(name, "say restart cancelled").catch(() => {});
    return r;
  }
  if (action === "pack" && sub === "install") {
    const { project } = await req.json();
    if (typeof project !== "string" || !/^[A-Za-z0-9]+$/.test(project)) return text("invalid project", 400);
    return Response.json(await packInstall(name, project));
  }
  if (action === "pack" && sub === "upload") {
    const data = new Uint8Array(await req.arrayBuffer());
    const original = (url.searchParams.get("name") ?? "pack.zip").replace(/[^A-Za-z0-9._ +-]/g, "_").slice(0, 120);
    return Response.json(await storePack(name, data, { title: original.replace(/\.zip$/i, ""), icon: null, project: null, version: null, original }));
  }
  if (action === "world" && sub === "action") {
    const { action: what, seed, type } = await req.json();
    if (!["reset", "nether", "end"].includes(what)) return text("unknown action", 400);
    if (what === "reset") {
      if (typeof seed !== "string" || seed.length > 64 || /[\r\n]/.test(seed)) return text("invalid seed", 400);
      if (!levelTypes.includes(type)) return text("invalid world type", 400);
      const txt = await Deno.readTextFile(props).catch(() => "");
      await Deno.writeTextFile(props, setProps(txt, { "level-seed": seed.trim(), "level-type": type }));
    }
    try { await startWorld(name, what); } catch (e) { return text(e.message, 409); }
    return text("ok");
  }
  if (action === "world" && sub === "upload") {
    if ((await worldJobs(name)).busy) return text("another world task is running", 409);
    if (!req.body) return text("empty upload", 400);
    const staged = `${root}/${name}/.import`;
    const f = await Deno.open(staged, { write: true, create: true, truncate: true });
    try { await req.body.pipeTo(f.writable); } catch { await Deno.remove(staged).catch(() => {}); return text("upload interrupted", 400); }
    await Deno.chown(staged, null, (await Deno.stat(`${root}/${name}`)).gid);
    await Deno.chmod(staged, 0o640);
    try { await startWorld(name, "import"); } catch (e) { return text(e.message, 409); }
    return text("ok");
  }
  if (action === "icon" && sub === "upload") {
    try {
      const id = await storeIcon(name, new Uint8Array(await req.arrayBuffer()));
      await useIcon(name, id);
      return Response.json({ id });
    } catch (e) { return text(e.message, 400); }
  }
  if (action === "icon" && sub === "use") {
    const { id } = await req.json();
    if (!validIcon(id)) return text("invalid icon", 400);
    try { await useIcon(name, id); } catch { return text("icon not found", 404); }
    return text("ok");
  }
  if (action === "pack" && sub === "settings") {
    const { required, prompt } = await req.json();
    const p = typeof prompt === "string" ? prompt.replace(/[\r\n]+/g, " ").slice(0, 200).trim() : "";
    const restarted = await applyProps(name, { "require-resource-pack": required ? "true" : "false", "resource-pack-prompt": p ? JSON.stringify({ text: p }) : "" });
    return Response.json({ restarted });
  }
  if (action === "mods" && sub === "install") {
    const { project } = await req.json();
    if (typeof project !== "string" || !/^[A-Za-z0-9]+$/.test(project)) return text("invalid project", 400);
    return Response.json(await install(name, project, await packs(name, kind), kind));
  }
  if (action === "player") {
    const { action: a, player, extra } = await req.json();
    const make = playerActions[a];
    if (!make) return text("unknown action", 400);
    if (a !== "whitelist" && !validPlayer(player)) return text("invalid player name", 400);
    if (!await running()) return text("server is not running", 409);
    const reason = typeof extra === "string" ? extra.replace(/[\r\n]+/g, " ").slice(0, 200).trim() : "";
    await command(name, make(player, reason));
    return text("ok");
  }
  if (action === "command") {
    if (!await running()) return text("server is not running", 409);
    return (await command(name, await req.text())) ? text("ok") : text("empty command", 400);
  }
  return text("not found", 404);
}

Deno.serve({ port: 4603, hostname: "127.0.0.1" }, async (req) => {
  try {
    const r = await route(req);
    if (new URL(req.url).pathname.startsWith("/api/")) try { r.headers.set("cache-control", "no-store"); } catch {}
    return r;
  } catch (e) {
    return text(e.message || "error", 500);
  }
});

const publicDir = Deno.args[1];
const publicPage = (await Deno.readTextFile(`${publicDir}/index.html`)).replaceAll("VERSION", publicDir.split("/").pop().slice(0, 8));
const publicHost = "mc.1f2t.org";
const memo = new Map();

async function cached(key, ttl, fn) {
  const c = memo.get(key);
  if (c && Date.now() - c.t < ttl) return c.v;
  if (c?.p) return c.p;
  const p = fn();
  memo.set(key, { ...c, p });
  try {
    const v = await p;
    memo.set(key, { t: Date.now(), v });
    return v;
  } catch (e) {
    memo.delete(key);
    throw e;
  }
}

async function publicServers() {
  return Promise.all([...names].filter((n) => servers[n].public !== false).map(async (n) => {
    const s = await status(n);
    return {
      name: n,
      version: s.version,
      type: s.type,
      address: `${publicHost}:${s.port}`,
      online: s.ready,
      icon: s.icon,
      players: s.players ? { online: s.players.online, max: s.players.max, list: s.players.list } : null,
      worlds: await worlds(n),
    };
  }));
}

async function publicRoute(req) {
  if (req.method !== "GET") return text("method not allowed", 405);
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
  if (parts[0] !== "api") return new Response(publicPage, { headers: { "content-type": "text/html; charset=utf-8" } });
  if (parts[1] === "servers" && parts.length === 2) return Response.json(await cached("servers", 10000, publicServers));
  const name = parts[1];
  if (!names.has(name) || servers[name].public === false) return text("unknown server", 404);
  const action = parts[2];
  if (action === "icon") {
    const data = await Deno.readFile(`${root}/${name}/server-icon.png`).catch(() => null);
    return data ? pngResponse(data) : text("no icon", 404);
  }
  if (action === "leaderboard") {
    const all = url.searchParams.has("all");
    return Response.json(await cached(`lb:${name}:${all}`, 30000, () => leaderboard(name, all)));
  }
  if (action === "history") return Response.json((history[name] ?? []).map(([t, p]) => [t, p]));
  if (action === "profile" && validPlayer(parts[3])) {
    const known = await cached(`known:${name}`, 30000, async () => Object.keys(await gameStats(name, true)));
    if (!known.includes(parts[3])) return text("unknown player", 404);
    const p = await cached(`profile:${name}:${parts[3]}`, 30000, () => profile(name, parts[3]));
    const { kicks: _, achieved, ...rest } = p;
    return Response.json({ ...rest, achievements: advList.map((a) => ({ ...a, t: a.id in achieved ? achieved[a.id] : undefined })) });
  }
  return text("not found", 404);
}

Deno.serve({ port: 4604, hostname: "127.0.0.1" }, async (req) => {
  try {
    const r = await publicRoute(req);
    if (new URL(req.url).pathname.startsWith("/api/")) try { r.headers.set("cache-control", "public, max-age=10"); } catch {}
    return r;
  } catch {
    return text("error", 500);
  }
});
