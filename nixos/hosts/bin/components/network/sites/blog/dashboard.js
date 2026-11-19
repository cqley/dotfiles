const $ = (s) => document.querySelector(s);
const store = (k, v) => {
  try {
    if (v === undefined) return localStorage.getItem(k) || "";
    v === null ? localStorage.removeItem(k) : localStorage.setItem(k, v);
  } catch {
    return "";
  }
};

for (const f of document.querySelectorAll("form[data-title]")) {
  f.addEventListener("submit", (e) => {
    if (!confirm(`delete "${f.dataset.title}"? this can't be undone.`)) e.preventDefault();
  });
}
if (new URLSearchParams(location.search).get("m") === "published") store("blogdraft", null);

const md = $("#md");
if (md) {
  const form = md.form, title = form.elements.title, preview = $("#preview"), status = $("#status");
  const fresh = form.hasAttribute("data-new"), max = Number(md.dataset.max);
  const state = () => title.value + "\0" + md.value;
  let saved = state(), timer;

  const say = (text, kind = "") => {
    status.textContent = text;
    status.className = "status " + kind;
  };


  const show = () => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      if (!md.value.trim()) return preview.innerHTML = '<p class="muted">nothing yet</p>';
      const res = await fetch("/preview", { method: "POST", body: md.value }).catch(() => null);
      if (res?.ok) preview.innerHTML = await res.text();
      else say("preview failed", "err");
    }, 200);
  };

  const draft = () => fresh && store("blogdraft", JSON.stringify({ title: title.value, md: md.value }));

  md.addEventListener("input", () => {
    show();
    draft();
  });
  title.addEventListener("input", draft);

  const insert = (text, from, to) => {
    md.focus();
    const start = md.selectionStart;
    if (!document.execCommand("insertText", false, text)) {
      md.setRangeText(text, md.selectionStart, md.selectionEnd, "end");
      md.dispatchEvent(new Event("input"));
    }
    if (from !== undefined) md.setSelectionRange(start + from, start + to);
  };

  const wrap = (before, after, placeholder) => {
    const sel = md.value.slice(md.selectionStart, md.selectionEnd) || placeholder;
    insert(before + sel + after, before.length, before.length + sel.length);
  };

  const lines = (make, strip) => {
    const v = md.value;
    const start = v.lastIndexOf("\n", md.selectionStart - 1) + 1;
    let end = v.indexOf("\n", md.selectionEnd);
    if (end === -1 || (md.selectionEnd > md.selectionStart && v[md.selectionEnd - 1] === "\n")) {
      end = end === -1 ? v.length : md.selectionEnd - 1;
    }
    md.setSelectionRange(start, end);
    const ls = v.slice(start, end).split("\n");
    const all = ls.every((l) => strip.test(l));
    const text = ls.map((l, i) => (all ? "" : make(i)) + l.replace(strip, "")).join("\n");
    insert(text, 0, text.length);
  };

  const block = (text) => {
    const before = md.value.slice(0, md.selectionStart);
    const lead = before === "" || before.endsWith("\n\n") ? "" : before.endsWith("\n") ? "\n" : "\n\n";
    insert(lead + text + "\n\n");
  };

  const commands = {
    bold: () => wrap("**", "**", "bold text"),
    italic: () => wrap("*", "*", "italic text"),
    strike: () => wrap("~~", "~~", "struck text"),
    h2: () => lines(() => "## ", /^#{1,6} /),
    h3: () => lines(() => "### ", /^#{1,6} /),
    quote: () => lines(() => "> ", /^> /),
    ul: () => lines(() => "- ", /^[-*] /),
    ol: () => lines((i) => `${i + 1}. `, /^\d+\. /),
    code: () => md.value.slice(md.selectionStart, md.selectionEnd).includes("\n") ? wrap("```\n", "\n```", "") : wrap("`", "`", "code"),
    rule: () => block("---"),
    link: () => {
      const sel = md.value.slice(md.selectionStart, md.selectionEnd) || "link text";
      insert(`[${sel}](https://)`, sel.length + 3, sel.length + 11);
    },
    image: () => $("#file").click(),
  };

  for (const b of document.querySelectorAll("[data-cmd]")) {
    b.addEventListener("mousedown", (e) => e.preventDefault());
    b.addEventListener("click", () => commands[b.dataset.cmd]());
  }

  addEventListener("keydown", (e) => {
    if (!(e.ctrlKey || e.metaKey)) return;
    const cmd = { b: "bold", i: "italic", k: "link" }[e.key.toLowerCase()];
    if (cmd && e.target === md) {
      e.preventDefault();
      commands[cmd]();
    }
    if (e.key.toLowerCase() === "s") {
      e.preventDefault();
      form.requestSubmit();
    }
  });

  const upload = async (files) => {
    const images = [...files].filter((f) => /^image\/(png|jpeg|gif|webp)$/.test(f.type));
    if (!images.length) return say("only png, jpg, gif and webp pictures", "err");
    for (const [i, f] of images.entries()) {
      say(`uploading picture ${i + 1}/${images.length}...`);
      const res = await fetch("/images", { method: "POST", headers: { "content-type": f.type }, body: f }).catch((e) => e);
      if (!res.ok) return say(String(res.ok === undefined ? res.message : await res.text()).slice(0, 120), "err");
      const alt = f.name.replace(/\.[^.]+$/, "").replace(/[\[\]]/g, "") || "picture";
      block(`![${alt}](${(await res.json()).url})`);
    }
    say(images.length === 1 ? "picture attached" : `${images.length} pictures attached`, "ok");
  };

  $("#file").addEventListener("change", (e) => {
    if (e.target.files.length) upload(e.target.files);
    e.target.value = "";
  });
  md.addEventListener("paste", (e) => {
    if (e.clipboardData?.files.length) {
      e.preventDefault();
      upload(e.clipboardData.files);
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

  form.addEventListener("submit", (e) => {
    if (md.value.length > max) {
      e.preventDefault();
      return say(`too long, cut ${(md.value.length - max).toLocaleString()} characters`, "err");
    }
    saved = state();
    say(fresh ? "publishing..." : "saving...");
  });

  addEventListener("beforeunload", (e) => {
    if (!fresh && state() !== saved) e.preventDefault();
  });

  if (fresh && !title.value && !md.value) {
    try {
      const d = JSON.parse(store("blogdraft") || "null");
      if (d && (d.title || d.md)) {
        title.value = d.title || "";
        md.value = d.md || "";
        show();
        say("draft restored");
      }
    } catch {}
  }
}
