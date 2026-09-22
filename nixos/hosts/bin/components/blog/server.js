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

const css = `
:root{--bg:#fff;--fg:#222;--dim:#888;--acc:#f2b8e2;--line:#ddd;--err:#e33;--ok:#5a5;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font-family:ui-monospace,monospace;font-size:14px;line-height:1.5;
  padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px);}
.wrap{max-width:60ch;margin:4rem auto;padding:0 1rem;}
h1{font-size:1rem;font-weight:normal;margin:0 0 1.5rem}
p{margin:0 0 1.2rem}
.date{color:var(--dim);font-size:.85em}
table{width:100%;border-collapse:collapse}
tr{border-bottom:1px solid var(--line)}
tr:last-child{border-bottom:none}
td{padding:.6rem 0;vertical-align:top}
td.d{color:var(--dim);white-space:nowrap;padding-right:1.2rem}
a{color:var(--fg);text-decoration:none}
a:hover,a:focus{color:var(--acc)}
.up{color:var(--dim)}
.up:hover,.up:focus{color:var(--acc)}
.post p{color:var(--fg)}
form{display:flex;flex-direction:column;gap:.6rem;margin-bottom:2rem}
input,textarea,button{font-family:inherit;font-size:inherit;background:var(--bg);color:var(--fg);
  border:1px solid var(--line);padding:.4rem .5rem;border-radius:0;outline:none;}
input:focus,textarea:focus{border-color:var(--acc)}
textarea{min-height:10rem;resize:vertical}
button{color:var(--acc);cursor:pointer;align-self:flex-start}
button:hover{border-color:var(--acc)}
.status{color:var(--dim);font-size:.85em}
.status.err{color:var(--err)}
.status.ok{color:var(--ok)}
.del{color:var(--err);font-size:.85em}
`;

function indexHtml() {
  return `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>blog</title><style>${css}</style></head><body><div class="wrap" id="app"></div>
<script>
function esc(s){return s.replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));}
async function posts(){return (await fetch("/api/posts")).json();}
async function render(){
  const hash=location.hash.slice(1);
  const app=document.getElementById("app");
  const list=await posts();
  if(!hash){
    app.innerHTML=list.length?\`<h1>blog</h1><table><tbody>\${list.map(p=>\`<tr>
      <td class="d">\${p.date}</td><td><a href="#\${p.slug}">\${p.slug}.md</a></td>
      </tr>\`).join("")}</tbody></table>\`:\`<h1>blog</h1><p>nothing posted yet.</p>\`;
    return;
  }
  const post=list.find(p=>p.slug===hash);
  if(!post){app.innerHTML='<p>no such file.</p><a class="up" href="#">../</a>';return;}
  app.innerHTML=\`<a class="up" href="#">../</a>
    <h1 style="margin-top:1.5rem">\${esc(post.title)}</h1>
    <p class="date" style="margin-bottom:1.5rem">\${post.date}</p>
    <div class="post">\${post.body.map(b=>\`<p>\${esc(b)}</p>\`).join("")}</div>\`;
}
addEventListener("hashchange",render);
render();
</script></body></html>`;
}

function adminHtml() {
  return `<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>blog admin</title><style>${css}</style></head><body><div class="wrap">
<h1>admin</h1>
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
    <td class="d">\${p.date}</td><td>\${esc(p.title)}</td>
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
</script></div></body></html>`;
}

Deno.serve({ port: 4600 }, async (req) => {
  const url = new URL(req.url);

  if (req.method === "GET" && url.pathname === "/") {
    return new Response(indexHtml(), { headers: { "content-type": "text/html" } });
  }
  if (req.method === "GET" && url.pathname === "/admin") {
    return new Response(adminHtml(), { headers: { "content-type": "text/html" } });
  }
  if (req.method === "GET" && url.pathname === "/api/posts") {
    const posts = await loadPosts();
    posts.sort((a, b) => b.date.localeCompare(a.date));
    return Response.json(posts);
  }
  if (req.method === "POST" && url.pathname === "/api/posts") {
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
  if (req.method === "DELETE" && url.pathname.startsWith("/api/posts/")) {
    if (!authed(req)) return new Response("unauthorized", { status: 401 });
    const slug = url.pathname.split("/").pop();
    const posts = await loadPosts();
    const next = posts.filter((p) => p.slug !== slug);
    await savePosts(next);
    return Response.json({ deleted: slug });
  }
  return new Response("not found", { status: 404 });
});
