const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const postsFile = `${dir}/posts.json`;
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

async function loadPosts() {
  try {
    return JSON.parse(await Deno.readTextFile(postsFile));
  } catch {
    return [];
  }
}
async function savePosts(posts) {
  await Deno.writeTextFile(postsFile, JSON.stringify(posts, null, 2));
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
        <td><a href="/${esc(p.slug)}">${esc(p.title)}</a></td>
      </tr>`).join("")}</tbody></table>`
    : `<p>nothing posted yet.</p>`;
  return layout("blog", `
    <h1>blog</h1>
    ${list}
  `);
}

function postPage(post) {
  return layout(post.title, `
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">${esc(post.title)}</h1>
    <p class="date" style="margin-bottom:1.5rem">${esc(post.date)}</p>
    <div class="post">${post.body.map((b) => `<p>${esc(b)}</p>`).join("")}</div>
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
        <textarea id="body" placeholder="paragraphs, separated by a blank line" required></textarea>
        <button type="submit">post</button>
        <span class="status" id="status">ready</span>
      </form>
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
        <td><a href="/\${p.slug}" target="_blank">\${esc(p.title)}</a></td>
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

    document.getElementById("new").onsubmit=async e=>{
      e.preventDefault();
      const status=document.getElementById("status");
      const title=document.getElementById("title").value;
      const body=document.getElementById("body").value.split(/\\n\\s*\\n/).map(s=>s.trim()).filter(Boolean);
      status.textContent="posting...";status.className="status";
      try{
        await api("/api/posts",{method:"POST",headers:{"content-type":"application/json"},
          body:JSON.stringify({title,body})});
        document.getElementById("title").value="";
        document.getElementById("body").value="";
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
    const posts = await loadPosts();
    posts.sort((a, b) => b.date.localeCompare(a.date));
    return new Response(indexPage(posts), { headers: { "content-type": "text/html" } });
  }

  if (req.method === "GET" && path === "/dashboard") {
    return new Response(dashboardPage(), { headers: { "content-type": "text/html" } });
  }

  if (path === "/api/posts" && req.method === "GET") {
    const posts = await loadPosts();
    posts.sort((a, b) => b.date.localeCompare(a.date));
    return Response.json(posts);
  }

  if (path === "/api/posts" && req.method === "POST") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const { title, body } = await req.json();
    if (!title || !Array.isArray(body) || !body.length) {
      return new Response("bad request", { status: 400 });
    }
    const posts = await loadPosts();
    let slug = slugify(title);
    let n = 2;
    while (posts.some((p) => p.slug === slug)) slug = `${slugify(title)}-${n++}`;
    const post = { slug, title, date: new Date().toISOString().slice(0, 10), body };
    posts.push(post);
    await savePosts(posts);
    return Response.json(post);
  }

  if (path.startsWith("/api/posts/") && req.method === "DELETE") {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const slug = path.split("/").pop();
    const posts = await loadPosts();
    const next = posts.filter((p) => p.slug !== slug);
    await savePosts(next);
    return Response.json({ deleted: slug });
  }

  if (req.method === "GET" && !path.startsWith("/api/")) {
    const slug = path.slice(1);
    const posts = await loadPosts();
    const post = posts.find((p) => p.slug === slug);
    if (post) {
      return new Response(postPage(post), { headers: { "content-type": "text/html" } });
    }
    return new Response(notFoundPage(), { status: 404, headers: { "content-type": "text/html" } });
  }

  return new Response("not found", { status: 404 });
});
