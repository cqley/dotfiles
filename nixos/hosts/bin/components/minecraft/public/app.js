const $=(id)=>document.getElementById(id);
function el(t,c,x){const e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e;}
const skins={};
function skin(n){return skins[n]??=fetch("/api/"+encodeURIComponent(srv.name)+"/skin/"+encodeURIComponent(n)).then((r)=>r.ok?r.json():null).catch(()=>null).then(async(s)=>{if(!s?.url)return null;const i=new Image();i.src=s.url;await i.decode().catch(()=>{});s.old=i.naturalHeight===32;return s;});}
function paint(e,s,x,y,ox,oy){e.style.backgroundImage=(ox!=null?"url("+s.url+"),":"")+"url("+s.url+")";e.style.backgroundPosition=(ox!=null?-ox+"em "+-oy+"em,":"")+-x+"em "+-y+"em";}
function head(n){const e=el("span","h");skin(n).then((s)=>{if(s)paint(e,s,8,8,40,8);});return e;}
function box(s,u,v,w,h,d,x,y,z,grow,flip){
  const b=el("span","cube"),g=grow||0;
  b.style.transform="translate3d("+x+"em,"+y+"em,"+z+"em)"+(flip?" scaleX(-1)":"")+(g?" scale3d("+(w+g)/w+","+(h+g)/h+","+(d+g)/d+")":"");
  for(const [fu,fv,fw,fh,t,k] of [[u+d,v+d,w,h,"translateZ("+d/2+"em)",""],[u+d+w+d,v+d,w,h,"rotateY(180deg) translateZ("+d/2+"em)","dk"],[u,v+d,d,h,"rotateY(-90deg) translateZ("+w/2+"em)","sd"],[u+d+w,v+d,d,h,"rotateY(90deg) translateZ("+w/2+"em)","sd"],[u+d,v,w,d,"rotateX(90deg) translateZ("+h/2+"em)","tp"],[u+d+w,v,w,d,"rotateX(-90deg) translateZ("+h/2+"em)","dk"]]){
    const f=el("i",k);
    f.style.cssText="width:"+fw+"em;height:"+fh+"em;margin:"+-fh/2+"em 0 0 "+-fw/2+"em;background-image:url("+s.url+");background-position:"+-fu+"em "+-fv+"em;transform:"+t;
    b.append(f);
  }
  return b;
}
function figure(n){
  const e=el("span","body"),m=el("span","model");e.append(m);
  skin(n).then((s)=>{
    if(!s)return;
    const w=s.slim?3:4,o=s.old,ax=4+w/2;
    const parts=[[0,0,8,8,8,0,-12,0],[16,16,8,12,4,0,-2,0],[40,16,w,12,4,-ax,-2,0],o?[40,16,w,12,4,ax,-2,0,0,1]:[32,48,w,12,4,ax,-2,0],[0,16,4,12,4,-2,10,0],o?[0,16,4,12,4,2,10,0,0,1]:[16,48,4,12,4,2,10,0]];
    const over=[[32,0,1],[16,32,.5],[40,32,.5],o?null:[48,48,.5],[0,32,.5],o?null:[0,48,.5]];
    parts.forEach((p,k)=>{
      const [u,v,pw,ph,pd,x,y,z,,flip]=p;
      m.append(box(s,u,v,pw,ph,pd,x,y,z,0,flip));
      const q=over[k];
      if(q&&!(o&&k))m.append(box(s,q[0],q[1],pw,ph,pd,x,y,z,q[2],flip));
    });
  });
  return e;
}
let ac;
function click(){
  try{
    ac??=new AudioContext();
    const t=ac.currentTime,o=ac.createOscillator(),g=ac.createGain();
    o.type="triangle";o.frequency.setValueAtTime(1500,t);o.frequency.exponentialRampToValueAtTime(450,t+.05);
    g.gain.setValueAtTime(.22,t);g.gain.exponentialRampToValueAtTime(.001,t+.07);
    o.connect(g).connect(ac.destination);o.start(t);o.stop(t+.08);
    const b=ac.createBuffer(1,ac.sampleRate*.015|0,ac.sampleRate),d=b.getChannelData(0);
    for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1)*(1-i/d.length)**3;
    const n=ac.createBufferSource(),f=ac.createBiquadFilter(),ng=ac.createGain();
    n.buffer=b;f.type="bandpass";f.frequency.value=2600;ng.gain.value=.35;
    n.connect(f).connect(ng).connect(ac.destination);n.start(t);
  }catch{}
}
document.addEventListener("click",(e)=>{if(e.target.closest?.(".btn"))click();});
const num=(n)=>n>=1e6?(n/1e6).toFixed(1)+"m":n>=1e4?Math.round(n/1e3)+"k":n>=1e3?(n/1e3).toFixed(1)+"k":String(Math.round(n));
function dur(ms){const m=Math.floor(ms/60000);if(m<60)return m+"m";const h=Math.floor(m/60);if(h<48)return h+"h "+(m%60)+"m";return Math.floor(h/24)+"d "+(h%24)+"h";}
const ago=(t)=>dur(Date.now()-t)+" ago";
const dist=(cm)=>cm>=100000?(cm/100000).toFixed(cm>=1e7?0:1)+" km":Math.round(cm/100)+" m";
const hearts=(h)=>num(h/2)+" ♥";
const day=(t)=>new Date(t).toLocaleDateString(undefined,{day:"numeric",month:"short",year:"numeric"}).toLowerCase();
const metrics=[["playtime","playtime",dur,"most played"],["mobKills","mob kills",num,"most kills"],["deaths","deaths",num,"most deaths"],["distance","distance",dist,"furthest"],["mined","blocks mined",num,"most mined"],["crafted","items crafted",num,null],["jumps","jumps",num,"most jumps"],["playerKills","player kills",num,null],["damageDealt","damage dealt",hearts,null],["damageTaken","damage taken",hearts,null],["fish","fish caught",num,"best fisher"],["bred","animals bred",num,null],["trades","villager trades",num,"best trader"],["enchants","items enchanted",num,null],["advancements","advancements",num,"most advancements"],["sleeps","nights slept",num,null]];
let list=[],srv=null,board=[],all=false;

function toast(t,x){$("toast")?.remove();const d=el("div","dark");d.id="toast";d.append(el("b",null,t));if(x)d.append(el("span",null,x));document.body.append(d);setTimeout(()=>d.remove(),2200);}
function copy(t){const a=el("textarea");a.value=t;a.style.cssText="position:fixed;top:0;opacity:0;font-size:16px;";document.body.append(a);a.select();a.setSelectionRange(0,t.length);let ok=false;try{ok=document.execCommand("copy");}catch{}a.remove();ok?toast("copied",t):toast("copy this",t);}
async function get(p){const r=await fetch("/api/"+p);if(!r.ok)throw new Error(await r.text());return r.json();}
function link(n,cls){const a=el("a",cls);a.href="/player/"+encodeURIComponent(n)+(srv&&list.length>1?"?s="+encodeURIComponent(srv.name):"");a.onclick=(e)=>{if(e.metaKey||e.ctrlKey)return;e.preventDefault();go(a.getAttribute("href"));};return a;}
function go(u){history.pushState(null,"",u);route();scrollTo(0,0);}
function slot(n){const s=el("span","slot");s.append(head(n));return s;}


function card(){
  const c=$("card");c.innerHTML="";c.className="";
  if(!srv)return;
  c.className="panel";
  const ic=el("span","slot");
  if(srv.icon){const i=el("img");i.src="/api/"+encodeURIComponent(srv.name)+"/icon?v="+srv.icon;i.alt="";ic.append(i);}else ic.append(el("span"));
  const t=el("div","t");
  t.append(el("h1",null,srv.name),el("div","m",srv.type+" "+srv.version));
  const ip=el("div","ip"),f=el("input","field");f.readOnly=true;f.value=srv.address;f.onclick=()=>f.select();
  const b=el("button","btn","copy");b.onclick=()=>copy(srv.address);
  ip.append(f,b);
  if(srv.map){const m=el("a","btn","map");m.href="/map/"+encodeURIComponent(srv.name)+"/";ip.append(m);}
  const s=el("div","s"),pg=el("span","ping"+(srv.online?"":" off"));
  for(let i=0;i<5;i++)pg.append(el("i"));
  const st=srv.online?el("span","on-t",srv.players?srv.players.online+"/"+srv.players.max+" online":"online"):el("span","off-t","offline");
  s.append(pg,st);
  c.append(ic,t,s,ip);
}

function picker(){
  const p=$("pick");p.innerHTML="";p.hidden=list.length<2;
  for(const s of list){const b=el("button","btn"+(s===srv?" on":""),s.name);b.onclick=()=>go("/?s="+encodeURIComponent(s.name));p.append(b);}
}

async function loadBoard(){
  board=await get(srv.name+"/leaderboard"+(all?"?all":"")).catch(()=>[]);
  records();renderBoard();players();
}

function scope(){
  const s=$("scope");s.innerHTML="";
  if(!srv.worlds)return;
  for(const [v,l] of [[false,"this world"],[true,"all time"]]){const b=el("button","btn"+(all===v?" on":""),l);b.onclick=()=>{if(all===v)return;all=v;scope();loadBoard();};s.append(b);}
}

function records(){
  const r=$("records");r.innerHTML="";
  for(const [k,,fmt,title] of metrics){
    if(!title)continue;
    const best=board.reduce((a,b)=>(b[k]||0)>(a?.[k]||0)?b:a,null);
    if(!best||!best[k])continue;
    const a=link(best.player,"dark"),t=el("div");
    t.append(el("span","k",title),el("b",null,fmt(best[k])),el("small",null,best.player));
    a.append(head(best.player),t);
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
    const a=link(x.player),c=el("span","c"),xp=el("span","xp"),bar=el("i");
    bar.style.width=(x[k]/max*100)+"%";xp.append(bar);
    c.append(el("span","nm",x.player),xp);
    a.append(el("span","r",String(i+1)),slot(x.player),c,el("span","v",fmt(x[k])));
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
    const a=link(x.player,"panel"),n=el("span","n");
    n.append(el("span",null,x.player),on.has(x.player)?el("small","on-t","online"):el("small",null,dur(x.playtime)));
    a.append(slot(x.player),n);
    g.append(a);
  }
  if(!rows.length)g.append(el("p","empty",f?"no match":"nobody yet"));
}

function online(){
  const o=$("online");o.innerHTML="";
  const l=srv.players?.list||[];
  $("ocount").textContent=srv.players?l.length+"/"+srv.players.max:"";
  const bar=el("div","bar");
  for(const n of l){const a=link(n);a.dataset.n=n;a.title=n;a.append(head(n));bar.append(a);}
  for(let i=l.length;i<Math.max(9,Math.ceil(l.length/9)*9);i++)bar.append(el("span","e"));
  o.append(bar);
  if(l.length){const t=el("div","names");l.forEach((n,i)=>{if(i)t.append(document.createTextNode(", "));const a=link(n);a.textContent=n;t.append(a);});o.append(t);}
  else o.append(el("p","empty",srv.online?"nobody right now":"server is offline"));
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
  const line="M"+xy.map((p,i)=>(i?"H"+p[0].toFixed(1)+"V":"")+(i?"":p[0].toFixed(1)+" ")+p[1].toFixed(1)).join("");
  const ns="http://www.w3.org/2000/svg";
  const svg=document.createElementNS(ns,"svg");svg.setAttribute("viewBox","0 0 "+W+" "+H);svg.setAttribute("preserveAspectRatio","none");
  const a=document.createElementNS(ns,"path");a.setAttribute("class","a");a.setAttribute("d",line+"L"+W+" "+H+"L0 "+H+"Z");
  const l=document.createElementNS(ns,"path");l.setAttribute("class","l");l.setAttribute("d",line);
  svg.append(a,l);
  const ax=el("div","ax");ax.append(el("span",null,ago(t0)),el("span",null,"now"));
  const d=el("div","dark");d.append(svg,ax);g.append(d);
}

function section(t,node){const s=el("div","sec");s.append(el("h2",null,t));return [s,node];}
function listOf(rows,fmt){const d=el("div","panel list");for(const [k,v] of rows)if(v){const r=el("div");r.append(el("span",null,String(k).replace(/_/g," ")),el("em",null,fmt?fmt(v):num(v)));d.append(r);}return d.childNodes.length?d:null;}

function achievements(ach,got){
  if(!got.length)return [];
  const s=el("div","sec");s.append(el("h2",null,"advancements"),el("span","d",got.length+" / "+ach.length));
  const tabs=el("div","pick sm tabs"),box=el("div","adv");
  const cats=[...(got.some((a)=>a.t)?["recent"]:[]),"story","nether","end","adventure","husbandry"];
  let cur=cats[0];
  const show=()=>{
    tabs.innerHTML="";box.innerHTML="";
    for(const c of cats){
      const n=ach.filter((a)=>a.cat===c);
      const b=el("button","btn"+(cur===c?" on":""),c==="recent"?c:c+" "+n.filter((a)=>"t" in a).length+"/"+n.length);
      b.onclick=()=>{cur=c;show();};tabs.append(b);
    }
    const rows=cur==="recent"?got.filter((a)=>a.t).sort((a,b)=>b.t-a.t).slice(0,12):ach.filter((a)=>a.cat===cur);
    for(const a of rows){
      const done="t" in a,open=done||!a.hidden;
      const r=el("div","panel "+(done?"done ":"no ")+a.frame),t=el("span","t");
      t.append(el("b",null,open?a.title.toLowerCase():"???"),el("small",null,open?a.desc.toLowerCase():"hidden"));
      if(done)t.append(el("em",null,a.t?day(a.t):"done"));r.append(t);
      box.append(r);
    }
  };
  show();
  return [s,tabs,box];
}

let seq=0;
async function profile(n){
  const my=++seq,m=$("player");m.innerHTML="";
  const back=el("a","btn back","← "+srv.name);back.href="/"+(list.length>1?"?s="+encodeURIComponent(srv.name):"");back.onclick=(e)=>{e.preventDefault();go(back.getAttribute("href"));};
  m.append(back);
  let p;
  try{p=await get(srv.name+"/profile/"+encodeURIComponent(n));}catch{if(my===seq)m.append(el("p","empty","no such player"));return;}
  if(my!==seq)return;
  document.title=n+" · mc";
  let useAll=!!p.total;
  const body=el("div");
  const draw=()=>{
    body.innerHTML="";
    const s=(useAll?p.total:p.stats)||{};
    const top=el("div","panel ph");
    const sl=el("span","slot");sl.append(figure(n));
    const t=el("div","t");
    t.append(el("h1",null,n),p.online?el("div","on-t","online now"):el("div","m",p.last?"last seen "+ago(p.last):"no sessions logged"));
    if(p.total){const sg=el("div","pick sm");for(const [v,l] of [[false,"this world"],[true,"all time"]]){const b=el("button","btn"+(useAll===v?" on":""),l);b.onclick=()=>{useAll=v;draw();};sg.append(b);}t.append(sg);}
    top.append(sl,t);
    const kv=el("div","kv");
    const cell=(k,v)=>{if(v==null||v===""||v==="0")return;const d=el("div","panel");d.append(el("span",null,k),el("b",null,v));kv.append(d);};
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
      const bars=el("div","panel bars"),max=s.travel[0][1];
      for(const [k,v] of s.travel){const r=el("div"),i=el("i");i.style.width=Math.max(1,v/max*100)+"%";const w=el("span","xp");w.append(i);r.append(el("span",null,k),w,el("em",null,dist(v)));bars.append(r);}
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
  setInterval(async()=>{const l=await get("servers").catch(()=>null);if(!l)return;list=l;srv=list.find((s)=>s.name===srv?.name)||list[0]||null;card();if(!$("home").hidden&&srv)online();},30000);
})();
