const $ = (id) => document.getElementById(id);

const store = {
  get(k) { try { return localStorage.getItem(k) || ""; } catch { return ""; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  del(k) { try { localStorage.removeItem(k); } catch {} },
};

let token = store.get("blogtoken");
let editing = null;
let savedState = "";

const md = $("md");
const title = $("title");
const preview = $("preview");
const status = $("status");

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function setStatus(text, kind = "") {
  status.textContent = text;
  status.className = "status" + (kind ? " " + kind : "");
}

async function api(path, opts = {}) {
  opts.headers = { ...opts.headers, authorization: "bearer " + token };
  const res = await fetch(path, opts);
  if (res.status === 401) {
    token = "";
    store.del("blogtoken");
    boot();
    throw new Error("unauthorized");
  }
  if (!res.ok) throw new Error(await res.text());
  return res;
}

function json(body) {
  return { headers: { "content-type": "application/json" }, body: JSON.stringify(body) };
}

function currentState() {
  return title.value + "\u0000" + md.value;
}

function dirty() {
  return currentState() !== savedState;
}

let previewTimer = null;
function schedulePreview() {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(async () => {
    if (!md.value.trim()) {
      preview.innerHTML = '<p class="muted">nothing yet</p>';
      return;
    }
    try {
      const res = await api("/api/preview", { method: "POST", ...json({ md: md.value }) });
      preview.innerHTML = await res.text();
    } catch {}
  }, 200);
}

function saveDraft() {
  if (!editing) store.set("blogdraft", JSON.stringify({ title: title.value, md: md.value }));
}

const maxPost = Number(md.dataset.max) || 20000;

function tooLong() {
  return md.value.length > maxPost;
}

function updateCounter() {
  const n = md.value.length;
  const counter = $("counter");
  counter.textContent = `${n.toLocaleString()} / ${maxPost.toLocaleString()}`;
  counter.className = "counter" + (n > maxPost ? " over" : n > maxPost * 0.9 ? " near" : "");
}

md.addEventListener("input", () => {
  updateCounter();
  schedulePreview();
  saveDraft();
});
title.addEventListener("input", saveDraft);

function insert(text, selectFrom, selectTo) {
  md.focus();
  const start = md.selectionStart;
  if (!document.execCommand("insertText", false, text)) {
    md.setRangeText(text, md.selectionStart, md.selectionEnd, "end");
    md.dispatchEvent(new Event("input"));
  }
  if (selectFrom !== undefined) md.setSelectionRange(start + selectFrom, start + selectTo);
}

function wrap(before, after, placeholder) {
  const sel = md.value.slice(md.selectionStart, md.selectionEnd) || placeholder;
  insert(before + sel + after, before.length, before.length + sel.length);
}

function selectLines() {
  const v = md.value;
  const start = v.lastIndexOf("\n", md.selectionStart - 1) + 1;
  let end = v.indexOf("\n", md.selectionEnd);
  if (end === -1 || (md.selectionEnd > md.selectionStart && v[md.selectionEnd - 1] === "\n")) {
    end = end === -1 ? v.length : md.selectionEnd - 1;
  }
  md.setSelectionRange(start, end);
  return v.slice(start, end);
}

function prefixLines(make, strip) {
  const lines = selectLines().split("\n");
  const all = lines.every((l) => strip.test(l));
  const out = lines.map((l, i) => (all ? l.replace(strip, "") : make(i) + l.replace(strip, "")));
  const text = out.join("\n");
  insert(text, 0, text.length);
}

function block(text) {
  const before = md.value.slice(0, md.selectionStart);
  const lead = before === "" || before.endsWith("\n\n") ? "" : before.endsWith("\n") ? "\n" : "\n\n";
  insert(lead + text + "\n\n");
}

const commands = {
  bold: () => wrap("**", "**", "bold text"),
  italic: () => wrap("*", "*", "italic text"),
  strike: () => wrap("~~", "~~", "struck text"),
  h2: () => prefixLines(() => "## ", /^#{1,6} /),
  h3: () => prefixLines(() => "### ", /^#{1,6} /),
  quote: () => prefixLines(() => "> ", /^> /),
  ul: () => prefixLines(() => "- ", /^[-*] /),
  ol: () => prefixLines((i) => `${i + 1}. `, /^\d+\. /),
  code: () => {
    const sel = md.value.slice(md.selectionStart, md.selectionEnd);
    if (sel.includes("\n")) wrap("```\n", "\n```", "");
    else wrap("`", "`", "code");
  },
  rule: () => block("---"),
  link: () => {
    const sel = md.value.slice(md.selectionStart, md.selectionEnd) || "link text";
    const text = `[${sel}](https://)`;
    insert(text, sel.length + 3, sel.length + 11);
  },
  image: () => $("file").click(),
};

document.querySelectorAll(".toolbar [data-cmd]").forEach((b) => {
  b.addEventListener("mousedown", (e) => e.preventDefault());
  b.addEventListener("click", () => commands[b.dataset.cmd]());
});

md.addEventListener("keydown", (e) => {
  if (!(e.ctrlKey || e.metaKey)) return;
  const k = e.key.toLowerCase();
  const map = { b: "bold", i: "italic", k: "link" };
  if (map[k]) {
    e.preventDefault();
    commands[map[k]]();
  }
});

document.addEventListener("keydown", (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s" && !$("main").classList.contains("hidden")) {
    e.preventDefault();
    $("editor").requestSubmit();
  }
});

async function upload(files) {
  const images = [...files].filter((f) => /^image\/(png|jpeg|gif|webp)$/.test(f.type));
  if (!images.length) {
    setStatus("only png, jpg, gif and webp pictures", "err");
    return;
  }
  for (const [i, f] of images.entries()) {
    setStatus(`uploading picture ${i + 1}/${images.length}...`);
    try {
      const res = await api("/api/images", { method: "POST", headers: { "content-type": f.type }, body: f });
      const { url } = await res.json();
      const alt = f.name.replace(/\.[^.]+$/, "").replace(/[\[\]]/g, "") || "picture";
      block(`![${alt}](${url})`);
    } catch (err) {
      setStatus(String(err.message || err).slice(0, 120), "err");
      return;
    }
  }
  setStatus(images.length === 1 ? "picture attached" : `${images.length} pictures attached`, "ok");
}

$("file").addEventListener("change", (e) => {
  if (e.target.files.length) upload(e.target.files);
  e.target.value = "";
});

md.addEventListener("paste", (e) => {
  const files = e.clipboardData?.files;
  if (files && files.length) {
    e.preventDefault();
    upload(files);
  }
});

md.addEventListener("dragover", (e) => {
  if ([...(e.dataTransfer?.types || [])].includes("Files")) {
    e.preventDefault();
    md.classList.add("drop");
  }
});
md.addEventListener("dragleave", () => md.classList.remove("drop"));
md.addEventListener("drop", (e) => {
  md.classList.remove("drop");
  if (e.dataTransfer?.files.length) {
    e.preventDefault();
    upload(e.dataTransfer.files);
  }
});

function resetEditor() {
  editing = null;
  title.value = "";
  md.value = "";
  $("editorhead").textContent = "new post";
  $("save").textContent = "publish";
  $("cancel").classList.add("hidden");
  preview.innerHTML = '<p class="muted">nothing yet</p>';
  savedState = currentState();
  updateCounter();
}

function loadDraft() {
  try {
    const d = JSON.parse(store.get("blogdraft") || "null");
    if (d && (d.title || d.md)) {
      title.value = d.title || "";
      md.value = d.md || "";
      schedulePreview();
      updateCounter();
      setStatus("draft restored");
    }
  } catch {}
}

async function startEdit(slug) {
  if (dirty() && !confirm("discard your unsaved changes?")) return;
  try {
    const post = await (await api("/api/posts/" + encodeURIComponent(slug))).json();
    editing = post.slug;
    title.value = post.title;
    md.value = post.md.replace(/\n$/, "");
    savedState = currentState();
    $("editorhead").textContent = "editing: " + post.title;
    $("save").textContent = "save changes";
    $("cancel").classList.remove("hidden");
    setStatus("editing");
    schedulePreview();
    updateCounter();
    $("editor").scrollIntoView({ behavior: "smooth", block: "start" });
    md.focus();
  } catch (err) {
    setStatus("couldn't load post", "err");
  }
}

$("cancel").onclick = () => {
  if (dirty() && !confirm("discard your changes?")) return;
  resetEditor();
  loadDraft();
  setStatus("ready");
};

$("editor").onsubmit = async (e) => {
  e.preventDefault();
  if (!title.value.trim() || !md.value.trim()) {
    setStatus("title and text are both needed", "err");
    return;
  }
  if (tooLong()) {
    setStatus(`too long, cut ${(md.value.length - maxPost).toLocaleString()} characters`, "err");
    return;
  }
  $("save").disabled = true;
  setStatus(editing ? "saving..." : "publishing...");
  try {
    if (editing) {
      const saved = await (await api("/api/posts/" + encodeURIComponent(editing), { method: "PUT", ...json({ title: title.value, md: md.value }) })).json();
      editing = saved.slug;
      savedState = currentState();
      $("editorhead").textContent = "editing: " + title.value.trim();
      setStatus("saved", "ok");
    } else {
      await api("/api/posts", { method: "POST", ...json({ title: title.value, md: md.value }) });
      store.del("blogdraft");
      resetEditor();
      setStatus("published", "ok");
    }
    loadList();
  } catch (err) {
    setStatus("failed: " + String(err.message || err).slice(0, 120), "err");
  } finally {
    $("save").disabled = false;
  }
};

$("settings").onsubmit = async (e) => {
  e.preventDefault();
  const s = $("settingsstatus");
  try {
    const { name } = await (await api("/api/settings", { method: "PUT", ...json({ name: $("sitename").value }) })).json();
    $("sitename").value = name;
    s.textContent = "renamed";
    s.className = "status ok";
  } catch (err) {
    s.textContent = "failed";
    s.className = "status err";
  }
};

async function loadList() {
  const posts = await (await fetch("/api/posts")).json();
  const tbody = document.querySelector("#list tbody");
  if (!posts.length) {
    tbody.innerHTML = '<tr><td class="muted">nothing posted yet.</td></tr>';
    return;
  }
  tbody.innerHTML = posts.map((p) => `<tr>
    <td class="d">${esc(p.date)}</td>
    <td><a href="/${esc(p.slug)}.md" target="_blank">${esc(p.title)}</a></td>
    <td class="rowactions">
      <a href="#" class="edit" data-slug="${esc(p.slug)}">edit</a>
      <a href="#" class="del" data-slug="${esc(p.slug)}" data-title="${esc(p.title)}">delete</a>
    </td>
  </tr>`).join("");
  tbody.querySelectorAll(".edit").forEach((el) => el.onclick = (e) => {
    e.preventDefault();
    startEdit(el.dataset.slug);
  });
  tbody.querySelectorAll(".del").forEach((el) => el.onclick = async (e) => {
    e.preventDefault();
    if (!confirm(`delete "${el.dataset.title}"? this can't be undone.`)) return;
    try {
      await api("/api/posts/" + encodeURIComponent(el.dataset.slug), { method: "DELETE" });
      if (editing === el.dataset.slug) resetEditor();
      loadList();
    } catch {}
  });
}

window.addEventListener("beforeunload", (e) => {
  if (editing && dirty()) e.preventDefault();
});

$("login").onsubmit = (e) => {
  e.preventDefault();
  token = $("pw").value;
  store.set("blogtoken", token);
  boot();
};

async function boot() {
  const show = (loggedIn) => {
    $("login").classList.toggle("hidden", loggedIn);
    $("main").classList.toggle("hidden", !loggedIn);
  };
  if (!token) return show(false);
  const res = await fetch("/api/check", { headers: { authorization: "bearer " + token } });
  if (!res.ok) {
    token = "";
    store.del("blogtoken");
    return show(false);
  }
  show(true);
  resetEditor();
  loadDraft();
  loadList();
}

boot();
