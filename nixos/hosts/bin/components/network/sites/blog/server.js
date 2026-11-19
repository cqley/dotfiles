import { marked } from "npm:marked@12";

const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const postsFile = `${dir}/posts.json`;
const postsDir = `${dir}/posts`;
const imagesDir = `${dir}/images`;
const settingsFile = `${dir}/settings.json`;

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

async function loadIndex() {
  try {
    return JSON.parse(await Deno.readTextFile(postsFile));
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) return [];
    throw e;
  }
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
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) return null;
    throw e;
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

function layout(body, extra = "", title = "本") {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${esc(title)}</title>
<link rel="stylesheet" href="/assets/style.css">
<script src="/assets/theme.js"></script>
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

function status(msg, err) {
  return `<span class="status ${err ? "err" : "ok"}" id="status">${esc(msg)}</span>`;
}

function dashPage(posts, msg = "") {
  const rows = posts.map((p) => `<tr>
    <td class="d">${esc(p.date)}</td>
    <td><a href="/${esc(p.slug)}.md">${esc(p.title)}</a></td>
    <td class="rows"><a href="/e/${esc(p.slug)}">edit</a><form method="post" action="/d/${esc(p.slug)}" data-title="${esc(p.title)}"><button class="del">delete</button></form></td>
  </tr>`).join("");
  return layout(`<main class="wrap dash">
    <p class="bar"><a href="/new">new post</a>${status(msg)}</p>
    ${rows ? `<table><tbody>${rows}</tbody></table>` : `<p class="muted">nothing posted yet.</p>`}
  </main>`, `<script src="/dashboard.js"></script>`, "dashboard");
}

const tools = [
  ["bold", "<b>b</b>"], ["italic", "<i>i</i>"], ["strike", "<s>s</s>"], ["h2", "h2"], ["h3", "h3"], ["quote", "&gt;"],
  ["ul", "&bull; list"], ["ol", "1. list"], ["code", "&lt;/&gt;"], ["rule", "&mdash;"], ["link", "link"], ["image", "picture"],
].map(([c, l]) => `<button type="button" data-cmd="${c}">${l}</button>`).join("");

function editPage(slug, title, md, msg = "", err = false) {
  return layout(`<main class="wrap dash wide">
    <form method="post" id="editor"${slug ? "" : " data-new"}>
      <p class="bar"><a href="/">../</a>${status(msg)}</p>
      <input name="title" class="title" value="${esc(title)}" placeholder="title" maxlength="200" required autocomplete="off">
      <div class="toolbar">${tools}<input type="file" id="file" accept="image/png,image/jpeg,image/gif,image/webp" multiple hidden></div>
      <div class="panes">
        <textarea name="md" id="md" placeholder="start writing..." required data-max="${maxPost}">${esc(md)}</textarea>
        <div class="markdown-body" id="preview">${md.trim() ? marked.parse(md) : `<p class="muted">nothing yet</p>`}</div>
      </div>
      <p class="bar"><button>${slug ? "save" : "publish"}</button>${slug ? `<a href="/">cancel</a>` : ""}</p>
    </form>
  </main>`, `<script src="/dashboard.js"></script>`, slug || "new");
}

function sniffImage(b) {
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "png";
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "jpg";
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x38) return "gif";
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 && b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) return "webp";
  return null;
}

async function readLimited(req, limit) {
  if (Number(req.headers.get("content-length") ?? 0) > limit) return null;
  const bytes = new Uint8Array(await req.arrayBuffer());
  return bytes.length > limit ? null : bytes;
}

function postError(title, md) {
  if (!title || !md.trim()) return "title and text are both needed";
  if (md.length > maxPost) return `too long, cut ${(md.length - maxPost).toLocaleString()} characters`;
  return "";
}

async function writeBody(slug, md) {
  await Deno.writeTextFile(`${postsDir}/${slug}.md`, md.endsWith("\n") ? md : md + "\n");
}

const see = (to) => new Response(null, { status: 303, headers: { location: to } });

async function site(req) {
  const url = new URL(req.url);
  const path = url.pathname;
  if (req.method !== "GET") return new Response("not found", { status: 404 });

  if (path === "/") return html(indexPage((await loadSettings()).name, sorted(await loadIndex())));

  if (path === "/blog.css") {
    return new Response(blogCss, { headers: { "content-type": "text/css; charset=utf-8" } });
  }

  if (path.startsWith("/images/")) {
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

  if (path.startsWith("/api/")) return new Response("not found", { status: 404 });

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

async function admin(req) {
  const url = new URL(req.url);
  const path = url.pathname;
  const get = req.method === "GET";

  if (!get && req.method !== "POST") return new Response("not found", { status: 404 });
  if (!get && req.headers.get("sec-fetch-site") === "cross-site") return new Response("forbidden", { status: 403 });

  if (get && path === "/") {
    return html(dashPage(sorted(await loadIndex()), url.searchParams.get("m") ?? ""));
  }

  if (get && path === "/dashboard.js") {
    return new Response(dashboardJs, { headers: { "content-type": "text/javascript; charset=utf-8" } });
  }

  if (get && path === "/new") return html(editPage("", "", ""));


  if (path === "/preview" && !get) return html(marked.parse(await req.text()));

  if (path === "/images" && !get) {
    const bytes = await readLimited(req, maxImage);
    if (!bytes) return new Response("picture is too big (max 15 MB)", { status: 413 });
    const ext = sniffImage(bytes);
    if (!ext) return new Response("only png, jpg, gif and webp pictures are allowed", { status: 400 });
    const id = Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, "0")).join("");
    await Deno.writeFile(`${imagesDir}/${id}.${ext}`, bytes);
    return Response.json({ url: `/images/${id}.${ext}` });
  }

  if (path === "/new" && !get) {
    const form = await req.formData();
    const title = String(form.get("title") ?? "").trim().slice(0, 200);
    const md = String(form.get("md") ?? "");
    const err = postError(title, md);
    if (err) return html(editPage("", title, md, err, true), 400);
    const posts = await loadIndex();
    const slug = uniqueSlug(title, posts);
    await writeBody(slug, md);
    posts.push({ slug, title, date: today() });
    await saveIndex(posts);
    return see("/?m=published");
  }

  const m = path.match(/^\/([ed])\/([^/]+)$/);
  if (m && slugPattern.test(m[2])) {
    const slug = m[2];
    const posts = await loadIndex();
    const post = posts.find((p) => p.slug === slug);

    if (m[1] === "d" && !get) {
      await saveIndex(posts.filter((p) => p.slug !== slug));
      await Deno.remove(`${postsDir}/${slug}.md`).catch((e) => { if (!(e instanceof Deno.errors.NotFound)) throw e; });
      return see("/?m=deleted");
    }

    if (m[1] === "e" && post) {
      if (get) {
        const md = await loadBody(slug);
        if (md !== null) return html(editPage(slug, post.title, md.replace(/\n$/, ""), url.searchParams.get("m") ?? ""));
      } else {
        const form = await req.formData();
        const title = String(form.get("title") ?? "").trim().slice(0, 200);
        const md = String(form.get("md") ?? "");
        const err = postError(title, md);
        if (err) return html(editPage(slug, title, md, err, true), 400);
        const newSlug = slugify(title) === slug ? slug : uniqueSlug(title, posts, post);
        await writeBody(newSlug, md);
        if (newSlug !== slug) {
          await Deno.remove(`${postsDir}/${slug}.md`);
          post.aliases = [...new Set([...(post.aliases ?? []), slug])].filter((a) => a !== newSlug);
          post.slug = newSlug;
        }
        post.title = title;
        post.updated = today();
        await saveIndex(posts);
        return see(`/e/${newSlug}?m=saved`);
      }
    }
  }

  if (get) return site(req);
  return new Response("not found", { status: 404 });
}

Deno.serve({ port: Number(Deno.env.get("PORT") ?? 4600), hostname: "127.0.0.1" }, site);
Deno.serve({ port: Number(Deno.env.get("ADMIN_PORT") ?? 4606), hostname: "127.0.0.1" }, admin);
