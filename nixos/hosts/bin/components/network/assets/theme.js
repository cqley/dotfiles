(() => {
  const r = document.documentElement;
  const domain = /(^|\.)1f2t\.org$/.test(location.hostname) ? ";domain=1f2t.org" : "";
  const read = () => {
    const c = document.cookie.match(/(?:^|; )theme=(light|dark)/);
    if (c) return c[1];
    try { return localStorage.getItem("theme"); } catch { return null; }
  };
  const t = read();
  if (t) r.dataset.theme = t;
  addEventListener("keydown", (e) => {
    if (!e.ctrlKey || e.altKey || e.metaKey || e.shiftKey || e.code !== "Space") return;
    e.preventDefault();
    r.dataset.theme = getComputedStyle(r).colorScheme.includes("dark") ? "light" : "dark";
    document.cookie = "theme=" + r.dataset.theme + ";path=/;max-age=31536000;samesite=lax" + domain;
    try { localStorage.setItem("theme", r.dataset.theme); } catch {}
  });
})();
