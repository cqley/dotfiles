(() => {
  document.addEventListener("click", (e) => {
    const c = e.target.closest("[data-confirm]");
    if (c && !confirm(c.dataset.confirm)) e.preventDefault();
  });
  const form = document.getElementById("up");
  if (!form) return;
  const done = document.getElementById("done");
  const el = (tag, text, cls) => {
    const n = document.createElement(tag);
    n.textContent = text;
    if (cls) n.className = cls;
    return n;
  };
  const send = (file, link) => {
    const name = file ? file.name : link;
    const fd = new FormData();
    for (const [k, v] of new FormData(form)) if (k !== "file" && k !== "url") fd.append(k, v);
    if (file) fd.append("file", file, file.name);
    else fd.append("url", link);
    const box = el("div", name + " …", "upload");
    done.prepend(box);
    const x = new XMLHttpRequest();
    x.open("POST", "/upload");
    x.setRequestHeader("Accept", "application/json");
    x.upload.onprogress = (e) => {
      if (e.lengthComputable) box.textContent = name + " " + Math.round(e.loaded / e.total * 100) + "%";
    };
    x.onerror = () => box.replaceChildren(el("span", name + ": failed", "err"));
    x.onload = () => {
      if (x.status !== 200) return box.replaceChildren(el("span", name + ": " + x.responseText.trim(), "err"));
      const r = JSON.parse(x.responseText)[0];
      const a = el("a", r.filename);
      a.href = r.url;
      const copy = el("button", "copy");
      copy.type = "button";
      copy.onclick = () => navigator.clipboard.writeText(r.url).then(() => copy.textContent = "copied");
      box.replaceChildren(a, copy, el("span", "delete key " + r.delete_key, "muted"));
    };
    x.send(fd);
  };
  const all = (files) => {
    const k = form.elements.key;
    if (!files.length || (k && !k.reportValidity())) return;
    for (const f of files) send(f);
  };
  form.elements.file.addEventListener("change", () => {
    all(form.elements.file.files);
    form.elements.file.value = "";
  });
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const u = form.elements.url;
    if (u.value.trim()) send(null, u.value.trim());
    u.value = "";
  });
  addEventListener("dragover", (e) => {
    e.preventDefault();
    document.body.classList.add("over");
  });
  addEventListener("dragleave", (e) => {
    if (!e.relatedTarget) document.body.classList.remove("over");
  });
  addEventListener("drop", (e) => {
    e.preventDefault();
    document.body.classList.remove("over");
    all(e.dataTransfer.files);
  });
  addEventListener("paste", (e) => {
    if (e.clipboardData.files.length) all(e.clipboardData.files);
  });
})();
