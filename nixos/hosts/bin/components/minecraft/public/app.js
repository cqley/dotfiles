const $=(id)=>document.getElementById(id);
function el(t,c,x){const e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e;}
function head(n,size,cls){const i=el("img",cls||"h");i.loading="lazy";i.alt="";i.src="https://mc-heads.net/avatar/"+encodeURIComponent(n)+"/"+(size||24);return i;}
const num=(n)=>n>=1e6?(n/1e6).toFixed(1)+"m":n>=1e4?Math.round(n/1e3)+"k":n>=1e3?(n/1e3).toFixed(1)+"k":String(Math.round(n));
function dur(ms){const m=Math.floor(ms/60000);if(m<60)return m+"m";const h=Math.floor(m/60);if(h<48)return h+"h "+(m%60)+"m";return Math.floor(h/24)+"d "+(h%24)+"h";}
const ago=(t)=>dur(Date.now()-t)+" ago";
const dist=(cm)=>cm>=100000?(cm/100000).toFixed(cm>=1e7?0:1)+" km":Math.round(cm/100)+" m";
const hearts=(h)=>num(h/2)+" ♥";
const day=(t)=>new Date(t).toLocaleDateString(undefined,{day:"numeric",month:"short",year:"numeric"});
const metrics=[["playtime","playtime",dur,"most played"],["mobKills","mob kills",num,"most kills"],["deaths","deaths",num,"most deaths"],["distance","distance",dist,"furthest"],["mined","blocks mined",num,"most mined"],["crafted","items crafted",num,null],["jumps","jumps",num,"most jumps"],["playerKills","player kills",num,null],["damageDealt","damage dealt",hearts,null],["damageTaken","damage taken",hearts,null],["fish","fish caught",num,"best fisher"],["bred","animals bred",num,null],["trades","villager trades",num,"best trader"],["enchants","items enchanted",num,null],["advancements","advancements",num,"most advancements"],["sleeps","nights slept",num,null]];
let list=[],srv=null,board=[],all=false;

function toast(t){const d=el("div",null,t);d.id="toast";document.body.append(d);setTimeout(()=>d.remove(),1800);}
function copy(t){const a=el("textarea");a.value=t;a.style.cssText="position:fixed;top:0;opacity:0;font-size:16px;";document.body.append(a);a.select();a.setSelectionRange(0,t.length);let ok=false;try{ok=document.execCommand("copy");}catch{}a.remove();toast(ok?"copied":t);}
async function get(p){const r=await fetch("/api/"+p);if(!r.ok)throw new Error(await r.text());return r.json();}
function link(n,cls){const a=el("a",cls);a.href="/player/"+encodeURIComponent(n)+(srv&&list[0]&&srv.name!==list[0].name?"?s="+encodeURIComponent(srv.name):"");a.onclick=(e)=>{if(e.metaKey||e.ctrlKey)return;e.preventDefault();go(a.getAttribute("href"));};return a;}
function go(u){history.pushState(null,"",u);route();scrollTo(0,0);}

$("theme").onclick=()=>{const r=document.documentElement;r.dataset.theme=r.dataset.theme==="light"?"dark":"light";try{localStorage.setItem("theme",r.dataset.theme);}catch{}};

function card(){
  const c=$("card");c.innerHTML="";
  if(!srv)return;
  if(srv.icon){const i=el("img");i.src="/api/"+encodeURIComponent(srv.name)+"/icon?v="+srv.icon;i.alt="";c.append(i);}
  const t=el("div","t"),h=el("h1");
  h.append(el("span","dot"+(srv.online?" on":"")),document.createTextNode(srv.name));
  const s=el("small");
  s.append(document.createTextNode((srv.online?(srv.players?srv.players.online+"/"+srv.players.max+" online":"online"):"offline")+" · "+srv.type+" "+srv.version+" · "));
  const a=el("a",null,srv.address);a.id="addr";a.href="#";a.title="copy";a.onclick=(e)=>{e.preventDefault();copy(srv.address);};
  s.append(a);t.append(h,s);c.append(t);
}

function picker(){
  const p=$("pick");p.innerHTML="";p.hidden=list.length<2;
  for(const s of list){const b=el("button",s===srv?"on":null,s.name);b.onclick=()=>go("/?s="+encodeURIComponent(s.name));p.append(b);}
}

async function loadBoard(){
  board=await get(srv.name+"/leaderboard"+(all?"?all":"")).catch(()=>[]);
  records();renderBoard();players();
}

function scope(){
  const s=$("scope");s.innerHTML="";
  if(!srv.worlds)return;
  for(const [v,l] of [[false,"this world"],[true,"all time"]]){const b=el("button",all===v?"on":null,l);b.onclick=()=>{if(all===v)return;all=v;scope();loadBoard();};s.append(b);}
}

function records(){
  const r=$("records");r.innerHTML="";
  for(const [k,,fmt,title] of metrics){
    if(!title)continue;
    const best=board.reduce((a,b)=>(b[k]||0)>(a?.[k]||0)?b:a,null);
    if(!best||!best[k])continue;
    const a=link(best.player);
    const who=el("div");who.append(head(best.player),document.createTextNode(best.player));
    a.append(el("span",null,title),el("b",null,fmt(best[k])),who);
    r.append(a);
  }
  if(!r.childNodes.length)r.append(el("p","empty","no stats yet"));
}

function renderBoard(){
  const b=$("board");b.innerHTML="";
  const [k,,fmt]=metrics.find((m)=>m[0]===$("by").value)||metrics[0];
  const rows=board.filter((x)=>x[k]>0).sort((a,b)=>b[k]-a[k]).slice(0,10);
  const max=rows[0]?.[k]||1;
  rows.forEach((x,i)=>{
    const a=link(x.player);
    const bar=el("i");bar.style.width=(x[k]/max*100)+"%";
    a.append(el("span","r",String(i+1)),head(x.player),el("span","nm",x.player),el("span","v",fmt(x[k])),bar);
    b.append(a);
  });
  if(!rows.length)b.append(el("p","empty","nobody yet"));
}

function players(){
  const g=$("players");g.innerHTML="";
  const f=$("find").value.trim().toLowerCase();
  const on=new Set(srv.players?.list||[]);
  const rows=[...board].sort((a,b)=>(on.has(b.player)-on.has(a.player))||b.playtime-a.playtime).filter((x)=>!f||x.player.toLowerCase().includes(f));
  for(const x of rows){
    const a=link(x.player),n=el("span","n");
    const s=el("span");s.textContent=x.player;
    n.append(s,el("small",null,on.has(x.player)?"online":dur(x.playtime)));
    a.append(head(x.player),n);
    g.append(a);
  }
  if(!rows.length)g.append(el("p","empty",f?"no match":"nobody yet"));
}

function online(){
  const o=$("online");o.innerHTML="";
  const l=srv.players?.list||[];
  $("ocount").textContent=srv.players?l.length+"/"+srv.players.max:"";
  for(const n of l){const a=link(n);a.append(head(n),document.createTextNode(n));o.append(a);}
  if(!l.length)o.append(el("p","empty",srv.online?"nobody right now":"server is offline"));
}

async function graph(){
  const h=await get(srv.name+"/history").catch(()=>[]);
  const g=$("graph");g.innerHTML="";
  const pts=h.filter((x)=>x[0]>Date.now()-86400000);
  if(pts.length<2){g.append(el("p","empty","not enough data yet"));$("peak").textContent="";return;}
  const t0=pts[0][0],t1=pts[pts.length-1][0],max=Math.max(1,...pts.map((x)=>x[1]));
  $("peak").textContent="peak "+max;
  const W=1000,H=100;
  const xy=pts.map((x)=>[(x[0]-t0)/(t1-t0||1)*W,H-x[1]/max*(H-8)-2]);
  const line="M"+xy.map((p)=>p[0].toFixed(1)+" "+p[1].toFixed(1)).join("L");
  const ns="http://www.w3.org/2000/svg";
  const svg=document.createElementNS(ns,"svg");svg.setAttribute("viewBox","0 0 "+W+" "+H);svg.setAttribute("preserveAspectRatio","none");
  const a=document.createElementNS(ns,"path");a.setAttribute("class","a");a.setAttribute("d",line+"L"+W+" "+H+"L0 "+H+"Z");
  const l=document.createElementNS(ns,"path");l.setAttribute("class","l");l.setAttribute("d",line);
  svg.append(a,l);
  const ax=el("div","ax");ax.append(el("span",null,ago(t0)),el("span",null,"now"));
  g.append(svg,ax);
}

function section(t,node){const s=el("div","sec");s.append(el("h2",null,t));return [s,node];}
function listOf(rows,fmt){const d=el("div","list");for(const [k,v] of rows)if(v){const r=el("div");r.append(el("span",null,String(k).replace(/_/g," ")),el("em",null,fmt?fmt(v):num(v)));d.append(r);}return d.childNodes.length?d:null;}

function achievements(ach,got){
  if(!got.length)return [];
  const s=el("div","sec");s.append(el("h2",null,"advancements"),el("span","d",got.length+" / "+ach.length));
  const tabs=el("div","seg sm tabs"),box=el("div","adv");
  const cats=[...(got.some((a)=>a.t)?["recent"]:[]),"story","nether","end","adventure","husbandry"];
  let cur=cats[0];
  const show=()=>{
    tabs.innerHTML="";box.innerHTML="";
    for(const c of cats){
      const n=ach.filter((a)=>a.cat===c);
      const b=el("button",cur===c?"on":null,c==="recent"?c:c+" "+n.filter((a)=>"t" in a).length+"/"+n.length);
      b.onclick=()=>{cur=c;show();};tabs.append(b);
    }
    const rows=cur==="recent"?got.filter((a)=>a.t).sort((a,b)=>b.t-a.t).slice(0,12):ach.filter((a)=>a.cat===cur);
    for(const a of rows){
      const done="t" in a,open=done||!a.hidden;
      const r=el("div",(done?"":"no ")+a.frame),t=el("span");
      t.append(el("b",null,open?a.title.toLowerCase():"???"),el("small",null,open?a.desc.toLowerCase():"hidden"));
      r.append(t,el("em",null,done?(a.t?day(a.t):"done"):""));
      box.append(r);
    }
  };
  show();
  return [s,tabs,box];
}

async function profile(n){
  const m=$("player");m.innerHTML="";
  const back=el("a","back","← "+srv.name);back.href="/"+(srv.name!==list[0].name?"?s="+encodeURIComponent(srv.name):"");back.onclick=(e)=>{e.preventDefault();go(back.getAttribute("href"));};
  m.append(back);
  let p;
  try{p=await get(srv.name+"/profile/"+encodeURIComponent(n));}catch{m.append(el("p","empty","no such player"));return;}
  document.title=n+" · mc";
  let useAll=!!p.total;
  const body=el("div");
  const draw=()=>{
    body.innerHTML="";
    const s=(useAll?p.total:p.stats)||{};
    const top=el("div","ph");
    const im=el("img");im.alt="";im.src="https://mc-heads.net/body/"+encodeURIComponent(n)+"/84";
    const t=el("div"),h=el("h1");
    h.append(el("span","dot"+(p.online?" on":"")),document.createTextNode(n));
    t.append(h,el("small",null,p.online?"online now":p.last?"last seen "+ago(p.last):"no sessions logged"));
    if(p.total){const sg=el("span","seg sm");sg.style.marginTop=".6rem";for(const [v,l] of [[false,"this world"],[true,"all time"]]){const b=el("button",useAll===v?"on":null,l);b.onclick=()=>{useAll=v;draw();};sg.append(b);}t.append(sg);}
    top.append(im,t);
    const kv=el("div","kv");
    const cell=(k,v)=>{if(v==null||v===""||v==="0")return;const d=el("div");d.append(el("span",null,k),document.createTextNode(v));kv.append(d);};
    cell("playtime",s.playtime?dur(s.playtime):p.playtime?dur(p.playtime):null);
    cell("sessions",p.sessions?String(p.sessions):null);
    cell("longest session",p.longest?dur(p.longest):null);
    cell("first seen",p.first?day(p.first):null);
    cell("deaths",num(s.deaths||0));
    cell("mob kills",num(s.mobKills||0));
    cell("player kills",num(s.playerKills||0));
    cell("blocks mined",num(s.mined||0));
    cell("items crafted",num(s.crafted||0));
    cell("distance",s.distance?dist(s.distance):null);
    cell("jumps",num(s.jumps||0));
    cell("damage dealt",s.damageDealt?hearts(s.damageDealt):null);
    cell("damage taken",s.damageTaken?hearts(s.damageTaken):null);
    cell("alive for",!useAll&&s.sinceDeath?dur(s.sinceDeath):null);
    cell("fish caught",num(s.fish||0));
    cell("villager trades",num(s.trades||0));
    cell("nights slept",num(s.sleeps||0));
    const ach=p.achievements||[],got=ach.filter((a)=>"t" in a);
    cell("advancements",ach.length?got.length+" / "+ach.length:null);
    body.append(top,kv);
    if(s.travel&&s.travel.length){
      const bars=el("div","bars"),max=s.travel[0][1];
      for(const [k,v] of s.travel){const r=el("div"),i=el("i");i.style.width=Math.max(1,v/max*100)+"%";const w=el("span");w.append(i);r.append(el("span",null,k),w,el("em",null,dist(v)));bars.append(r);}
      body.append(...section("travel",bars));
    }
    const cols=el("div","cols");
    for(const [t,rows] of [["mined",s.topMined],["killed",s.topKilled],["killed by",s.killedBy],["crafted",s.topCrafted]]){const l=rows&&listOf(rows);if(l){const c=el("div");c.append(...section(t,l));cols.append(c);}}
    if(cols.childNodes.length)body.append(cols);
    const recent=el("div","cols");
    const dead=listOf((p.recentDeaths||[]).map((x)=>[x.text,x.t]),(t)=>ago(t));
    if(dead){const c=el("div");c.append(...section("deaths",dead));recent.append(c);}
    if(recent.childNodes.length)body.append(recent);
    body.append(...achievements(ach,got));
  };
  draw();
  m.append(body);
}

async function route(){
  const q=new URLSearchParams(location.search);
  srv=list.find((s)=>s.name===q.get("s"))||list[0]||null;
  $("none").hidden=!!srv;
  card();
  const m=location.pathname.match(/^\/player\/([A-Za-z0-9_]{1,16})\/?$/);
  picker();if(m)$("pick").hidden=true;
  $("home").hidden=!srv||!!m;
  $("player").hidden=!srv||!m;
  if(!srv)return;
  if(m){profile(m[1]);return;}
  document.title="mc · "+srv.name;
  online();scope();graph();loadBoard();
}

for(const [k,l] of metrics){const o=el("option",null,l);o.value=k;$("by").append(o);}
$("by").onchange=renderBoard;
$("find").oninput=players;
window.addEventListener("popstate",route);
(async()=>{
  list=await get("servers").catch(()=>[]);
  route();
  setInterval(async()=>{const l=await get("servers").catch(()=>null);if(!l)return;list=l;const q=new URLSearchParams(location.search);srv=list.find((s)=>s.name===q.get("s"))||list[0]||null;card();if(!$("home").hidden&&srv)online();},30000);
})();
