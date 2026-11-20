const $ = (s) => document.querySelector(s);
const text = $("textarea"), find = $("#find"), make = $("#new");
let dirty = false, sel = 0;
if (text) {
  text.oninput = () => { dirty = true; };
  text.form.onsubmit = () => { dirty = false; };
}
addEventListener("beforeunload", (e) => { if (dirty) e.preventDefault(); });

const items = () => [...document.querySelectorAll(".list:not([hidden]) li:not([hidden]) a")];
const mark = () => items().forEach((a, i) => a.classList.toggle("sel", i === sel));
const pick = (d) => { const n = items().length; sel = n ? (sel + d + n) % n : 0; mark(); items()[sel]?.scrollIntoView({ block: "nearest" }); };
const drop = (a) => {
  const m = a?.getAttribute("href").match(/^\/n\/(.+?)(?:\.md|\/)$/);
  if (!m || !confirm("delete " + decodeURIComponent(m[1]) + "?")) return;
  const f = document.createElement("form");
  f.method = "post";
  f.action = "/d/" + m[1];
  document.body.append(f);
  f.submit();
};

if (find) {
  const pre = find.dataset.dir ? find.dataset.dir + "/" : "";
  find.oninput = () => {
    const q = find.value.trim(), lq = q.toLowerCase(), name = pre + q.replace(/\.md$/, "");
    let exact = false;
    for (const li of document.querySelectorAll("#all li:not(#new)")) {
      li.hidden = !li.textContent.slice(pre.length).toLowerCase().includes(lq);
      exact ||= li.textContent === name;
    }
    for (const el of document.querySelectorAll("#dir, #empty")) el.hidden = !!q;
    $("#all").hidden = !q;
    make.hidden = !q || exact;
    make.firstChild.textContent = "new: " + name;
    make.firstChild.href = "/e/" + name.split("/").map(encodeURIComponent).join("/");
    sel = 0;
    mark();
  };
  find.onkeydown = (e) => {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") { e.preventDefault(); pick(e.key === "ArrowDown" ? 1 : -1); }
    if (e.key === "Enter") { e.preventDefault(); items()[sel]?.click(); }
    if (e.key === "Escape") { find.value = ""; find.oninput(); find.blur(); }
  };
  if (location.hash === "#find") find.focus();
  mark();
}

addEventListener("keydown", (e) => {
  const mod = e.ctrlKey || e.metaKey;
  if (mod && text && (e.key === "s" || e.key === "Enter")) { e.preventDefault(); dirty = false; text.form.requestSubmit(); return; }
  if (mod && e.key === "k") { e.preventDefault(); find ? find.focus() : location = "/#find"; return; }
  if (e.target.closest("input, textarea")) { if (e.key === "Escape" && text) history.back(); return; }
  if (mod || e.altKey) return;
  const run = {
    "/": () => (find ? find.focus() : location = "/#find", true),
    t: () => location = "/today",
    e: () => $("#edit") && ($("#edit").click(), true),
    j: () => find && (pick(1), true),
    k: () => find && (pick(-1), true),
    d: () => find && items()[sel] && (drop(items()[sel]), true),
    ArrowDown: () => find && (pick(1), true),
    ArrowUp: () => find && (pick(-1), true),
    Enter: () => find && items()[sel] && (items()[sel].click(), true),
    Escape: () => location.pathname !== "/" && (location = $(".head a:last-of-type:not(#edit)")?.href || "/"),
  }[e.key];
  if (run?.()) e.preventDefault();
});
