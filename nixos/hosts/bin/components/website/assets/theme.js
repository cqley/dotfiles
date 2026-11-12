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
  const dark = () => getComputedStyle(r).colorScheme.includes("dark");
  const title = (b) => { b.title = dark() ? "light mode" : "dark mode"; };
  const toggle = (b) => {
    r.dataset.theme = dark() ? "light" : "dark";
    document.cookie = "theme=" + r.dataset.theme + ";path=/;max-age=31536000;samesite=lax" + domain;
    try { localStorage.setItem("theme", r.dataset.theme); } catch {}
    title(b);
  };
  const init = () => {
    let b = document.getElementById("theme");
    if (!b) {
      b = document.createElement("button");
      b.id = "theme";
      b.type = "button";
      b.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>';
      document.body.append(b);
    }
    title(b);
    b.addEventListener("click", () => toggle(b));
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
