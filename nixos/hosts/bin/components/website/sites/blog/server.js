import { marked } from "npm:marked@12";

const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const postsFile = `${dir}/posts.json`;
const postsDir = `${dir}/posts`;
const tokenFile = `${dir}/token`;

await Deno.mkdir(postsDir, { recursive: true });

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

async function loadIndex() {
  let raw;
  try {
    raw = JSON.parse(await Deno.readTextFile(postsFile));
  } catch {
    return [];
  }
  let changed = false;
  for (const p of raw) {
    if (Array.isArray(p.body)) {
      await Deno.writeTextFile(`${postsDir}/${p.slug}.md`, p.body.join("\n\n") + "\n");
      delete p.body;
      changed = true;
    }
  }
  if (changed) await Deno.writeTextFile(postsFile, JSON.stringify(raw, null, 2));
  return raw;
}
async function saveIndex(posts) {
  await Deno.writeTextFile(postsFile, JSON.stringify(posts, null, 2));
}

async function loadBody(slug) {
  try {
    return await Deno.readTextFile(`${postsDir}/${slug}.md`);
  } catch {
    return null;
  }
}

function slugify(s) {
  return s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function authed(req) {
  return req.headers.get("authorization") === `bearer ${token}`;
}

function esc(s) {
  return String(s).replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
}

function layout(title, body) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title>
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

function indexPage(posts) {
  const list = posts.length
    ? `<table><tbody>${posts.map((p) => `<tr>
        <td class="d">${esc(p.date)}</td>
        <td><a href="/${esc(p.slug)}.md">${esc(p.title)}</a></td>
      </tr>`).join("")}</tbody></table>`
    : `<p>nothing posted yet.</p>`;
  return layout("blog", `
    <h1>blog</h1>
    ${list}
  `);
}

function postPage(post, md) {
  return layout(post.title, `
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">${esc(post.title)}</h1>
    <p class="date" style="margin-bottom:1.5rem">${esc(post.date)}</p>
    <div class="markdown-body">${marked.parse(md)}</div>
  `);
}

function notFoundPage() {
  return layout("blog", `
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">404</h1>
    <p>no such post.</p>
  `);
}

function dashboardPage() {
  const body = `
    <h1>dashboard</h1>
    <form id="login" style="display:none">
      <input id="pw" type="password" placeholder="token" autocomplete="off">
      <button type="submit">unlock</button>
    </form>
    <div id="main" style="display:none">
      <form id="new">
        <input id="title" placeholder="title" required>
        <textarea id="md" placeholder="markdown" required style="min-height:14rem;font-family:ui-monospace,monospace"></textarea>
        <button type="submit">post</button>
        <span class="status" id="status">ready</span>
      </form>
      <div class="file-card">
        <div class="file-card-header"><span class="name">preview</span></div>
        <div class="file-card-body markdown-body" id="preview"><p class="muted">nothing yet</p></div>
      </div>
      <table id="list"><tbody></tbody></table>
    </div>
    <script>
    function esc(s){return s.replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));}
    let token=localStorage.getItem("blog-token")||"";

    async function api(path,opts={}){
      opts.headers={...opts.headers,authorization:"bearer "+token};
      const res=await fetch(path,opts);
      if(res.status===401){token="";localStorage.removeItem("blog-token");boot();throw new Error("unauthorized");}
      return res;
    }

    async function loadList(){
      const posts=await (await fetch("/api/posts")).json();
      document.querySelector("#list tbody").innerHTML=posts.map(p=>\`<tr>
        <td class="d">\${p.date}</td>
        <td><a href="/\${p.slug}.md" target="_blank">\${esc(p.title)}</a></td>
        <td><a class="del" href="#" data-slug="\${p.slug}">delete</a></td>
        </tr>\`).join("");
      document.querySelectorAll(".del").forEach(el=>el.onclick=async e=>{
        e.preventDefault();
        await api("/api/posts/"+el.dataset.slug,{method:"DELETE"});
        loadList();
      });
    }

    document.getElementById("login").onsubmit=e=>{
      e.preventDefault();
      token=document.getElementById("pw").value;
      localStorage.setItem("blog-token",token);
      boot();
    };

    let previewTimer=null;
    document.getElementById("md").addEventListener("input",e=>{
      clearTimeout(previewTimer);
      previewTimer=setTimeout(async()=>{
        const md=e.target.value;
        const preview=document.getElementById("preview");
        if(!md){preview.innerHTML='<p class="muted">nothing yet</p>';return;}
        try{
          const res=await api("/api/preview",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({md})});
          preview.innerHTML=await res.text();
        }catch{}
      },250);
    });

    document.getElementById("new").onsubmit=async e=>{
      e.preventDefault();
      const status=document.getElementById("status");
      const title=document.getElementById("title").value;
      const md=document.getElementById("md").value;
      status.textContent="posting...";status.className="status";
      try{
        await api("/api/posts",{method:"POST",headers:{"content-type":"application/json"},
          body:JSON.stringify({title,md})});
        document.getElementById("title").value="";
        document.getElementById("md").value="";
        document.getElementById("preview").innerHTML='<p class="muted">nothing yet</p>';
        status.textContent="posted";status.className="status ok";
        loadList();
      }catch(err){
        status.textContent="failed";status.className="status err";
      }
    };

    async function boot(){
      if(!token){
        document.getElementById("login").style.display="flex";
        document.getElementById("main").style.display="none";
        return;
      }
      try{
        await api("/api/posts",{method:"GET"});
        document.getElementById("login").style.display="none";
        document.getElementById("main").style.display="block";
        loadList();
      }catch{}
    }
    boot();
    </script>`;
  return layout("blog dashboard", body);
}

Deno.serve({ port: 4600 }, async (req) => {
  const url = new URL(req.url);
  const path = url.pathname;

  if (req.method === "GET" && path === "/") {
    const posts = await loadIndex();
    posts.sort((a, b) => b.date.localeCompare(a.date));
    return new Response(indexPage(posts), { headers: { "content-type": "text/html" } });
  }

  if (req.method === "GET" && path === "/dashboard") {
    return new Response(dashboardPage(), { headers: { "content-type": "text/html" } });
  }

  if (path === "/api/posts" && req.method === "GET") {
    const posts = await loadIndex();
    posts.sort((a, b) => b.date.localeCompare(a.date));
    return Response.json(posts);
  }

  if (path === "/api/preview" && req.method === "POST") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const { md } = await req.json();
    return new Response(marked.parse(md ?? ""), { headers: { "content-type": "text/html" } });
  }

  if (path === "/api/posts" && req.method === "POST") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const { title, md } = await req.json();
    if (!title || typeof md !== "string" || !md.trim()) {
      return new Response("bad request", { status: 400 });
    }
    const posts = await loadIndex();
    let slug = slugify(title);
    let n = 2;
    while (posts.some((p) => p.slug === slug)) slug = `${slugify(title)}-${n++}`;
    const post = { slug, title, date: new Date().toISOString().slice(0, 10) };
    await Deno.writeTextFile(`${postsDir}/${slug}.md`, md.endsWith("\n") ? md : md + "\n");
    posts.push(post);
    await saveIndex(posts);
    return Response.json(post);
  }

  if (path.startsWith("/api/posts/") && req.method === "DELETE") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const slug = path.split("/").pop();
    const posts = await loadIndex();
    const next = posts.filter((p) => p.slug !== slug);
    await saveIndex(next);
    try { await Deno.remove(`${postsDir}/${slug}.md`); } catch {}
    return Response.json({ deleted: slug });
  }

  if (req.method === "GET" && !path.startsWith("/api/")) {
    const postMatch = path.match(/^\/([^/]+)\.md$/);
    if (postMatch) {
      const slug = postMatch[1];
      const posts = await loadIndex();
      const post = posts.find((p) => p.slug === slug);
      const md = post ? await loadBody(slug) : null;
      if (post && md !== null) {
        return new Response(postPage(post, md), { headers: { "content-type": "text/html" } });
      }
      return new Response(notFoundPage(), { status: 404, headers: { "content-type": "text/html" } });
    }

    const bareMatch = path.match(/^\/([^/]+)$/);
    if (bareMatch) {
      const posts = await loadIndex();
      if (posts.some((p) => p.slug === bareMatch[1])) {
        return Response.redirect(`${url.origin}/${bareMatch[1]}.md`, 301);
      }
    }

    return new Response(notFoundPage(), { status: 404, headers: { "content-type": "text/html" } });
  }

  return new Response("not found", { status: 404 });
});