const filesDir = "/var/lib/linx-server/files";
const metaDir = "/var/lib/linx-server/meta";
const siteUrl = "https://host.1f2t.org";

const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const tokenFile = `${dir}/token`;

async function ensureToken() {
  try {
    return (await Deno.readTextFile(tokenFile)).trim();
  } catch {
    const t = crypto.randomUUID().replaceAll("-", "");
    await Deno.writeTextFile(tokenFile, t);
    console.log(`admin token: ${t}`);
    return t;
  }
}
const token = await ensureToken();

function authed(req) {
  return req.headers.get("authorization") === `bearer ${token}`;
}

function safeName(name) {
  return typeof name === "string" && name.length > 0 && name !== "." && !name.includes("/") && !name.includes("..");
}

function esc(s) {
  return String(s).replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
}

async function listFiles() {
  const out = [];
  for await (const entry of Deno.readDir(filesDir)) {
    if (!entry.isFile) continue;
    const stat = await Deno.stat(`${filesDir}/${entry.name}`);
    let mimetype = null;
    let expiry = null;
    try {
      const meta = JSON.parse(await Deno.readTextFile(`${metaDir}/${entry.name}.json`));
      mimetype = meta.mimetype ?? null;
      expiry = meta.expiry ?? null;
    } catch {}
    out.push({
      name: entry.name,
      size: stat.size,
      mtime: stat.mtime ? stat.mtime.getTime() / 1000 : null,
      mimetype,
      expiry,
    });
  }
  out.sort((a, b) => (b.mtime ?? 0) - (a.mtime ?? 0));
  return out;
}

function layout(body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>files dashboard</title>
<link rel="icon" type="image/svg+xml" href="/assets/cat.svg">
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<main class="wrap">
${body}
</main>
</body>
</html>`;
}

function dashboardPage() {
  const body = `
    <h1>files</h1>
    <form id="login" style="display:none">
      <input id="pw" type="password" placeholder="token" autocomplete="off">
      <button type="submit">unlock</button>
    </form>
    <div id="main" style="display:none">
      <table id="list"><tbody></tbody></table>
    </div>
    <script>
    function esc(s){return s.replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));}
    function fmtBytes(n){
      if(!n||n<=0) return "0 B";
      const u=["B","KB","MB","GB","TB"];let i=0,v=n;
      while(v>=1024&&i<u.length-1){v/=1024;i++;}
      return (i===0?v:v.toFixed(v<10?2:1))+" "+u[i];
    }
    let token=localStorage.getItem("files-token")||"";

    async function api(path,opts={}){
      opts.headers={...opts.headers,authorization:"bearer "+token};
      const res=await fetch(path,opts);
      if(res.status===401){token="";localStorage.removeItem("files-token");boot();throw new Error("unauthorized");}
      return res;
    }

    async function loadList(){
      const files=await (await api("/dashboard/api/files")).json();
      document.querySelector("#list tbody").innerHTML=files.length?files.map(f=>\`<tr>
        <td><a href="${siteUrl}/\${encodeURIComponent(f.name)}" target="_blank">\${esc(f.name)}</a></td>
        <td class="d">\${fmtBytes(f.size)}</td>
        <td class="d">\${f.mimetype?esc(f.mimetype):"-"}</td>
        <td><a class="del" href="#" data-name="\${esc(f.name)}">delete</a></td>
        </tr>\`).join(""):'<tr><td colspan="4">no files uploaded yet.</td></tr>';
      document.querySelectorAll(".del").forEach(el=>el.onclick=async e=>{
        e.preventDefault();
        if(!confirm("delete "+el.dataset.name+"?")) return;
        await api("/dashboard/api/files/"+encodeURIComponent(el.dataset.name),{method:"DELETE"});
        loadList();
      });
    }

    document.getElementById("login").onsubmit=e=>{
      e.preventDefault();
      token=document.getElementById("pw").value;
      localStorage.setItem("files-token",token);
      boot();
    };

    async function boot(){
      if(!token){
        document.getElementById("login").style.display="flex";
        document.getElementById("main").style.display="none";
        return;
      }
      try{
        await loadList();
        document.getElementById("login").style.display="none";
        document.getElementById("main").style.display="block";
      }catch{
        document.getElementById("login").style.display="flex";
        document.getElementById("main").style.display="none";
      }
    }
    boot();
    </script>`;
  return layout(body);
}

Deno.serve({ port: 4601, hostname: "127.0.0.1" }, async (req) => {
  const url = new URL(req.url);
  const path = url.pathname;

  if (req.method === "GET" && (path === "/dashboard" || path === "/dashboard/")) {
    return new Response(dashboardPage(), { headers: { "content-type": "text/html" } });
  }

  if (path === "/dashboard/api/files" && req.method === "GET") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    return Response.json(await listFiles());
  }

  if (path.startsWith("/dashboard/api/files/") && req.method === "DELETE") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const name = decodeURIComponent(path.slice("/dashboard/api/files/".length));
    if (!safeName(name)) return new Response("bad request", { status: 400 });
    try { await Deno.remove(`${filesDir}/${name}`); } catch {}
    try { await Deno.remove(`${metaDir}/${name}.json`); } catch {}
    return Response.json({ deleted: name });
  }

  return new Response("not found", { status: 404 });
});
