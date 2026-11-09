import { marked } from "npm:marked@12";
import { timingSafeEqual } from "node:crypto";

const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const postsFile = `${dir}/posts.json`;
const postsDir = `${dir}/posts`;
const imagesDir = `${dir}/images`;
const settingsFile = `${dir}/settings.json`;
const tokenFile = `${dir}/token`;

const here = new URL(".", import.meta.url);
const dashboardJs = await Deno.readTextFile(new URL("dashboard.js", here));
const blogCss = await Deno.readTextFile(new URL("blog.css", here));

const maxImage = 15 * 1024 * 1024;
const maxPost = 20000;
const slugPattern = /^[a-z0-9-]+$/;
const imagePattern = /^[a-f0-9]{32}\.(png|jpg|gif|webp)$/;
const imageTypes = { png: "image/png", jpg: "image/jpeg", gif: "image/gif", webp: "image/webp" };

await Deno.mkdir(postsDir, { recursive: true });
await Deno.mkdir(imagesDir, { recursive: true });

async function ensureToken() {
  try {
    return (await Deno.readTextFile(tokenFile)).trim();
  } catch {
    const t = Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, "0")).join("");
    await Deno.writeTextFile(tokenFile, t, { mode: 0o600 });
    console.log("new admin token written to " + tokenFile);
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
  if (changed) await saveIndex(raw);
  return raw;
}

async function saveIndex(posts) {
  await Deno.writeTextFile(`${postsFile}.tmp`, JSON.stringify(posts, null, 2));
  await Deno.rename(`${postsFile}.tmp`, postsFile);
}

function sorted(posts) {
  return [...posts].sort((a, b) => b.date.localeCompare(a.date));
}

async function loadBody(slug) {
  try {
    return await Deno.readTextFile(`${postsDir}/${slug}.md`);
  } catch {
    return null;
  }
}

async function loadSettings() {
  try {
    const s = JSON.parse(await Deno.readTextFile(settingsFile));
    return { name: typeof s.name === "string" && s.name.trim() ? s.name : "blog" };
  } catch {
    return { name: "blog" };
  }
}

function slugify(s) {
  return s.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "post";
}

function uniqueSlug(title, posts, self = null) {
  const taken = new Set();
  for (const p of posts) {
    if (p === self) continue;
    taken.add(p.slug);
    for (const a of p.aliases ?? []) taken.add(a);
  }
  const base = slugify(title);
  let slug = base;
  let n = 2;
  while (taken.has(slug)) slug = `${base}-${n++}`;
  return slug;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function html(body, status = 200) {
  return new Response(body, { status, headers: { "content-type": "text/html; charset=utf-8" } });
}

function cleanTitle(t) {
  return typeof t === "string" ? t.trim().slice(0, 200) : "";
}

function layout(body, extra = "", title = "本") {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title>
<link rel="icon" type="image/svg+xml" href="/assets/cat.svg">
<link rel="stylesheet" href="/assets/style.css">
<link rel="stylesheet" href="/blog.css">
</head>
<body>
${body}
${extra}
</body>
</html>`;
}

function indexPage(name, posts) {
  const list = posts.length
    ? `<table><tbody>${posts.map((p) => `<tr>
        <td class="d">${esc(p.date)}</td>
        <td><a href="/${esc(p.slug)}.md">${esc(p.title)}</a></td>
      </tr>`).join("")}</tbody></table>`
    : `<p>nothing posted yet.</p>`;
  return layout(`<main class="wrap">
    <h1>${esc(name)}</h1>
    ${list}
  </main>`);
}

function postPage(name, post, md) {
  return layout(`<main class="wrap post">
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">${esc(post.title)}</h1>
    <p class="date" style="margin-bottom:1.5rem">${esc(post.date)}</p>
    <div class="markdown-body">${marked.parse(md)}</div>
  </main>`, "", `${post.slug}.md`);
}

function notFoundPage(name) {
  return layout(`<main class="wrap">
    <a class="up" href="/">../</a>
    <h1 style="margin-top:1.5rem">404</h1>
    <p>no such post.</p>
  </main>`);
}

function dashboardPage(name) {
  return layout(`<main class="wrap wide">
    <div class="dashhead">
      <a class="up" href="/">../</a>
      <h1>dashboard</h1>
    </div>

    <form id="login" class="hidden">
      <input id="pw" type="password" placeholder="token" autocomplete="off">
      <button type="submit">unlock</button>
    </form>

    <div id="main" class="hidden">
      <section class="panel">
        <h2>blog name</h2>
        <form id="settings" class="inline">
          <input id="sitename" maxlength="80" placeholder="blog" value="${esc(name)}">
          <button type="submit">rename</button>
          <span class="status" id="settingsstatus"></span>
        </form>
      </section>

      <section class="panel">
        <h2 id="editorhead">new post</h2>
        <form id="editor" class="editor">
          <input id="title" class="titleinput" placeholder="title" maxlength="200" required autocomplete="off">
          <div class="toolbar" role="toolbar" aria-label="formatting">
            <button type="button" data-cmd="bold" title="bold (ctrl+b)"><b>b</b></button>
            <button type="button" data-cmd="italic" title="italic (ctrl+i)"><i>i</i></button>
            <button type="button" data-cmd="strike" title="strikethrough"><s>s</s></button>
            <span class="sep"></span>
            <button type="button" data-cmd="h2" title="heading">h2</button>
            <button type="button" data-cmd="h3" title="small heading">h3</button>
            <button type="button" data-cmd="quote" title="quote">&gt;</button>
            <span class="sep"></span>
            <button type="button" data-cmd="ul" title="list">&bull; list</button>
            <button type="button" data-cmd="ol" title="numbered list">1. list</button>
            <button type="button" data-cmd="code" title="code">&lt;/&gt;</button>
            <button type="button" data-cmd="rule" title="divider">&mdash;</button>
            <span class="sep"></span>
            <button type="button" data-cmd="link" title="link (ctrl+k)">link</button>
            <button type="button" data-cmd="image" title="attach picture">picture</button>
            <input type="file" id="file" accept="image/png,image/jpeg,image/gif,image/webp" multiple hidden>
          </div>
          <div class="panes">
            <div class="pane">
              <textarea id="md" placeholder="start writing..." required data-max="${maxPost}"></textarea>
            </div>
            <div class="pane">
              <div class="markdown-body previewbody" id="preview"><p class="muted">nothing yet</p></div>
            </div>
          </div>
          <div class="actions">
            <button type="submit" id="save">publish</button>
            <button type="button" id="cancel" class="ghost hidden">cancel edit</button>
            <span class="status" id="status">ready</span>
            <span class="counter" id="counter"></span>
          </div>
        </form>
      </section>

      <section class="panel">
        <h2>posts</h2>
        <table id="list"><tbody></tbody></table>
      </section>
    </div>
  </main>`, `<script src="/dashboard.js"></script>`);
}

function sniffImage(bytes) {
  const b = bytes;
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "png";
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "jpg";
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x38) return "gif";
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 && b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) return "webp";
  return null;
}

async function readLimited(req, limit) {
  if (Number(req.headers.get("content-length") ?? 0) > limit) return null;
  if (!req.body) return new Uint8Array();
  const chunks = [];
  let size = 0;
  for await (const chunk of req.body) {
    size += chunk.length;
    if (size > limit) return null;
    chunks.push(chunk);
  }
  const out = new Uint8Array(size);
  let off = 0;
  for (const c of chunks) {
    out.set(c, off);
    off += c.length;
  }
  return out;
}

async function readJson(req) {
  const bytes = await readLimited(req, 2 * 1024 * 1024);
  if (!bytes) return null;
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

const unauthorized = () => new Response("unauthorized", { status: 401 });
const bad = (msg = "bad request") => new Response(msg, { status: 400 });

Deno.serve({ port: Number(Deno.env.get("PORT") ?? 4600), hostname: "127.0.0.1" }, async (req) => {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;

  if (method === "GET" && path === "/") {
    return html(indexPage((await loadSettings()).name, sorted(await loadIndex())));
  }

  if (method === "GET" && path === "/dashboard") {
    return html(dashboardPage((await loadSettings()).name));
  }

  if (method === "GET" && path === "/dashboard.js") {
    return new Response(dashboardJs, { headers: { "content-type": "text/javascript; charset=utf-8" } });
  }

  if (method === "GET" && path === "/blog.css") {
    return new Response(blogCss, { headers: { "content-type": "text/css; charset=utf-8" } });
  }

  if (method === "GET" && path.startsWith("/images/")) {
    const name = path.slice("/images/".length);
    if (!imagePattern.test(name)) return new Response("not found", { status: 404 });
    try {
      const data = await Deno.readFile(`${imagesDir}/${name}`);
      return new Response(data, {
        headers: {
          "content-type": imageTypes[name.split(".").pop()],
          "cache-control": "public, max-age=31536000, immutable",
          "x-content-type-options": "nosniff",
        },
      });
    } catch {
      return new Response("not found", { status: 404 });
    }
  }

  if (path === "/api/check" && method === "GET") {
    return (await authed(req)) ? new Response("ok") : unauthorized();
  }

  if (path === "/api/posts" && method === "GET") {
    return Response.json(sorted(await loadIndex()));
  }

  if (path === "/api/settings" && method === "PUT") {
    if (!(await authed(req))) return unauthorized();
    const body = await readJson(req);
    const name = typeof body?.name === "string" ? body.name.trim().slice(0, 80) : "";
    if (!name) return bad("name can't be empty");
    await Deno.writeTextFile(settingsFile, JSON.stringify({ name }, null, 2));
    return Response.json({ name });
  }

  if (path === "/api/preview" && method === "POST") {
    if (!(await authed(req))) return unauthorized();
    const body = await readJson(req);
    return html(marked.parse(typeof body?.md === "string" ? body.md : ""));
  }

  if (path === "/api/images" && method === "POST") {
    if (!(await authed(req))) return unauthorized();
    const bytes = await readLimited(req, maxImage);
    if (!bytes) return new Response("picture is too big (max 15 MB)", { status: 413 });
    const ext = sniffImage(bytes);
    if (!ext) return bad("only png, jpg, gif and webp pictures are allowed");
    const id = Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, "0")).join("");
    await Deno.writeFile(`${imagesDir}/${id}.${ext}`, bytes);
    return Response.json({ url: `/images/${id}.${ext}` });
  }

  if (path === "/api/posts" && method === "POST") {
    if (!(await authed(req))) return unauthorized();
    const body = await readJson(req);
    const title = cleanTitle(body?.title);
    const md = body?.md;
    if (!title || typeof md !== "string" || !md.trim()) return bad();
    if (md.length > maxPost) return bad(`posts can be at most ${maxPost} characters`);
    const posts = await loadIndex();
    const slug = uniqueSlug(title, posts);
    const post = { slug, title, date: today() };
    await Deno.writeTextFile(`${postsDir}/${slug}.md`, md.endsWith("\n") ? md : md + "\n");
    posts.push(post);
    await saveIndex(posts);
    return Response.json(post);
  }

  const postApi = path.match(/^\/api\/posts\/([^/]+)$/);
  if (postApi) {
    const slug = postApi[1];
    if (!slugPattern.test(slug)) return bad();

    if (method === "GET") {
      if (!(await authed(req))) return unauthorized();
      const post = (await loadIndex()).find((p) => p.slug === slug);
      const md = post ? await loadBody(slug) : null;
      if (!post || md === null) return new Response("not found", { status: 404 });
      return Response.json({ ...post, md });
    }

    if (method === "PUT") {
      if (!(await authed(req))) return unauthorized();
      const body = await readJson(req);
      const title = cleanTitle(body?.title);
      const md = body?.md;
      if (!title || typeof md !== "string" || !md.trim()) return bad();
      if (md.length > maxPost) return bad(`posts can be at most ${maxPost} characters`);
      const posts = await loadIndex();
      const post = posts.find((p) => p.slug === slug);
      if (!post) return new Response("not found", { status: 404 });
      const newSlug = slugify(title) === slug ? slug : uniqueSlug(title, posts, post);
      await Deno.writeTextFile(`${postsDir}/${newSlug}.md`, md.endsWith("\n") ? md : md + "\n");
      if (newSlug !== slug) {
        await Deno.remove(`${postsDir}/${slug}.md`).catch(() => {});
        post.aliases = [...new Set([...(post.aliases ?? []), slug])].filter((a) => a !== newSlug);
        post.slug = newSlug;
      }
      post.title = title;
      post.updated = today();
      await saveIndex(posts);
      return Response.json(post);
    }

    if (method === "DELETE") {
      if (!(await authed(req))) return unauthorized();
      const posts = await loadIndex();
      await saveIndex(posts.filter((p) => p.slug !== slug));
      await Deno.remove(`${postsDir}/${slug}.md`).catch(() => {});
      return Response.json({ deleted: slug });
    }
  }

  if (method === "GET" && !path.startsWith("/api/")) {
    const { name } = await loadSettings();
    const postMatch = path.match(/^\/([^/]+)\.md$/);
    if (postMatch) {
      const slug = postMatch[1];
      const posts = await loadIndex();
      const post = posts.find((p) => p.slug === slug);
      const md = post ? await loadBody(slug) : null;
      if (post && md !== null) return html(postPage(name, post, md));
      const moved = posts.find((p) => p.aliases?.includes(slug));
      if (moved) return Response.redirect(`${url.origin}/${moved.slug}.md`, 301);
      return html(notFoundPage(name), 404);
    }

    const bareMatch = path.match(/^\/([^/]+)$/);
    if (bareMatch) {
      const post = (await loadIndex()).find((p) => p.slug === bareMatch[1] || p.aliases?.includes(bareMatch[1]));
      if (post) return Response.redirect(`${url.origin}/${post.slug}.md`, 301);
    }

    return html(notFoundPage(name), 404);
  }

  return new Response("not found", { status: 404 });
});
