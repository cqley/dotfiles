const dir = Deno.env.get("STATE_DIRECTORY") ?? ".";
const scenesDir = `${dir}/scenes`;
const maxScene = 5 * 1024 * 1024;
const maxTotal = 2 * 1024 * 1024 * 1024;
const idPattern = /^[A-Za-z0-9]{24}$/;
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

await Deno.mkdir(scenesDir, { recursive: true });

let used = 0;
for await (const e of Deno.readDir(scenesDir)) {
  if (e.isFile) used += (await Deno.stat(`${scenesDir}/${e.name}`)).size;
}

function newId() {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
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

const tooLarge = () => Response.json({ error_class: "RequestTooLargeError" }, { status: 413 });

Deno.serve({ port: 4602, hostname: "127.0.0.1" }, async (req) => {
  const path = new URL(req.url).pathname;

  if (req.method === "POST" && path === "/api/v2/post/") {
    const data = await readLimited(req, maxScene);
    if (!data) return tooLarge();
    if (data.length === 0) return Response.json({ error_class: "EmptyRequestError" }, { status: 400 });
    if (used + data.length > maxTotal) return Response.json({ error_class: "StorageFullError" }, { status: 507 });
    const id = newId();
    await Deno.writeFile(`${scenesDir}/${id}`, data, { createNew: true });
    used += data.length;
    return Response.json({ id });
  }

  const get = path.match(/^\/api\/v2\/([A-Za-z0-9]+)$/);
  if (req.method === "GET" && get) {
    if (!idPattern.test(get[1])) return new Response("not found", { status: 404 });
    try {
      const data = await Deno.readFile(`${scenesDir}/${get[1]}`);
      return new Response(data, {
        headers: { "content-type": "application/octet-stream", "cache-control": "public, max-age=31536000, immutable" },
      });
    } catch {
      return new Response("not found", { status: 404 });
    }
  }

  return new Response("not found", { status: 404 });
});
