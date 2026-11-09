const range=86400000;
let icons={},pendingAt=0,sel=decodeURIComponent(location.pathname.split("/")[1]||""),es=null,cur=null,hist=[],hi=0,pending=null,tab="console",propsDirty=false,lastBackup=null,lastPlayers=0,modsChanged={},known=[],matches=[],mi=0;
async function refresh(){
  let list;
  try{list=await (await api("servers")).json();}catch(e){return;}
  const s=list.find((x)=>x.name===sel);
  $("list").innerHTML="";
  if(!s){$("view").hidden=true;const e=el("div","empty","no server called "+sel+" · ");const a=el("a",null,"dashboard");a.href="/dashboard";e.append(a);$("list").append(e);return;}
  $("view").hidden=false;
  const ph=phase(s);
  const d=el("div","srv sel "+ph);
  const top=el("div","top");
  const ik=s.name+s.icon;
  if(s.icon&&!icons[ik])icons[ik]=img("/api/"+encodeURIComponent(s.name)+"/icon/current?v="+s.icon,"si");
  if(s.icon)top.append(icons[ik]);
  top.append(el("span","dot"),el("span",null,s.name),el("span","state",ph));
  const bar=el("div","bar"),i=el("i");bar.append(i);
  i.style.width=Math.min(100,s.used/s.limit*100)+"%";
  d.append(top,el("div","meta m",(s.players?s.players.online+"/"+s.players.max+" players · ":"")+(s.used?gb(s.used):"0 GB")+" / "+s.memory+(s.since?" · up "+ago(s.since):"")),el("div","meta",s.type+" "+s.version+" · port "+s.port+(s.players?" · "+s.players.online+"/"+s.players.max+" players"+(s.players.pendingMax?" ("+s.players.pendingMax+" after restart)":""):"")),bar,el("div","meta",(s.used?gb(s.used):"0 GB")+" / "+s.memory+" · "+s.cpu+"% cpu"+(s.since?" · up "+ago(s.since):"")));
  if(s.lag)d.append(el("div","meta lag","lagging · "+s.lag.count+"× in 10 min · up to "+(s.lag.max/1000).toFixed(1)+"s behind"));
  $("list").append(d);
  cur=s;render();
  if(tab==="tasks")loadTasks();
  if(tab==="players"&&!$("players").contains(document.activeElement)&&Date.now()-lastPlayers>5000)loadPlayers();
}
function render(){
  const s=cur,ph=phase(s);
  const up=s.state==="active"||s.state==="activating";
  document.querySelectorAll("[data-a]").forEach((b)=>{
    const a=b.dataset.a;
    if(pending===a)return;
    b.classList.remove("busy");
    b.textContent=a;
    b.disabled=pending!==null||(a==="start"?up||s.state==="deactivating":!up);
  });
  if(pending){
    const done=(pending==="start"&&ph==="online")||(pending==="stop"&&ph==="offline")||(pending==="restart"&&ph==="online"&&s.since&&s.since>pendingAt)||ph==="failed";
    if(done){
      toast(ph==="failed"?s.name+" failed, check the console":s.name+(pending==="stop"?" stopped":" is online"),ph==="failed"?"err":"ok");
      if(pending!=="stop"){modsChanged[s.name+"mod"]=false;modsChanged[s.name+"datapack"]=false;}
      if(tab==="settings")loadIcons();
      pending=null;render();
    }
  }
  $("cmd").disabled=s.state!=="active";
  $("cmd").placeholder=s.state!=="active"?"server is offline":$("chat").checked?"message everyone":"command";
  const van=s.type==="vanilla";
  document.querySelector("[data-k=mod]").hidden=van;
  if(van&&kind==="mod"){setKind("datapack");if(tab==="mods"){setUrl(false);loadMods();}}
  if(tab==="mods")showChanged();
  if(!$("save").disabled)saveLabel();
}
async function loadKnown(){try{known=(await (await api(sel+"/players")).json()).known;}catch{}}
function loadTab(){
  if(!sel)return;
  if(tab==="players")loadPlayers();
  if(tab==="activity")loadActivity();
  if(tab==="mods")(kind==="pack"?loadPack():loadMods());
  if(tab==="stats")loadStats();
  if(tab==="tasks"){loadTasks();loadBackups();loadCrashes();}
  if(tab==="settings"){loadIcons();loadProps();}
  if(tab==="world")loadWorld();
}
function connect(){
  es=new EventSource("/api/"+sel+"/console");
  let first=true;
  es.onopen=()=>{first=true;};
  es.onmessage=(e)=>{if(first){$("log").textContent="";first=false;}line(e.data);};
}
function isChat(t){
  const i=t.indexOf("]: ");
  const raw=i<0?t:t.slice(i+3);
  if(/^(Player |Disguised )?[Cc]hat: /.test(raw))return true;
  const m=raw.replace(/^System chat: /,"");
  return m.startsWith("<")||m.startsWith("[Server]")||m.startsWith("[Not Secure]")||m.endsWith(" joined the game")||m.endsWith(" left the game");
}
function line(t,cls){
  const l=$("log");
  const s=el("span",null,t+"\n");
  if(cls)s.className=cls;
  else if(t.includes("/ERROR]")||t.includes("Exception")||t.startsWith("\tat "))s.className="e";
  else if(t.includes("/WARN]")||t.startsWith("WARNING"))s.className="w";
  if(!isChat(t)&&cls!=="c")s.classList.add("x");
  const f=$("filter").value.toLowerCase();
  if(f&&!t.toLowerCase().includes(f))s.classList.add("h");
  l.append(s);
  while(l.childNodes.length>3000)l.removeChild(l.firstChild);
  if($("follow").checked)l.scrollTop=l.scrollHeight;
}
$("filter").oninput=()=>{
  const f=$("filter").value.toLowerCase();
  for(const s of $("log").children)s.classList.toggle("h",!!f&&!s.textContent.toLowerCase().includes(f));
  if($("follow").checked)$("log").scrollTop=$("log").scrollHeight;
};
$("chat").onchange=()=>{
  $("log").classList.toggle("chat",$("chat").checked);
  $("log").scrollTop=$("log").scrollHeight;
  if(cur)render();
  suggest();
};
$("clear").onclick=()=>{$("log").textContent="";};
document.querySelectorAll("[data-a]").forEach((b)=>b.onclick=async()=>{
  if(!sel)return;
  const a=b.dataset.a;
  if(a!=="start"&&cur&&cur.players&&cur.players.online>0&&!confirm(a+" "+sel+"? "+cur.players.online+" player(s) online"))return;
  pending=a;pendingAt=Date.now()-1000;
  b.classList.add("busy");b.textContent=a==="stop"?"stopping…":a==="start"?"starting…":"restarting…";
  document.querySelectorAll("[data-a]").forEach((x)=>x.disabled=x!==b);
  try{await post(sel+"/"+a);toast(a+" requested for "+sel);}
  catch(e){toast(a+" failed: "+e.message,"err");pending=null;}
  refresh();
});
async function send(v){
  line("> "+v,"c");
  try{await post(sel+"/command",v);}
  catch(e){line("! "+e.message,"e");toast(e.message,"err");}
}
const P="player";
const modes=["survival","creative","adventure","spectator"];
const grammar={
  help:[],list:[],seed:[],stop:[],reload:[],setworldspawn:[],"save-on":[],"save-off":[],"save-all":[["flush"]],
  say:[],me:[],msg:[P],tell:[P],w:[P],kick:[P],ban:[P],pardon:[P],op:[P],deop:[P],kill:[P],clear:[P],spawnpoint:[P],
  tp:[P,P],teleport:[P,P],give:[P,["minecraft:diamond","minecraft:netherite_ingot","minecraft:elytra","minecraft:totem_of_undying","minecraft:golden_apple","minecraft:ender_pearl"]],
  effect:[["give","clear"],P,["minecraft:speed","minecraft:night_vision","minecraft:regeneration","minecraft:resistance","minecraft:haste","minecraft:invisibility"]],
  xp:[["add","set","query"],P],experience:[["add","set","query"],P],
  gamemode:[modes,P],defaultgamemode:[modes],
  difficulty:[["peaceful","easy","normal","hard"]],
  time:[["set","add","query"],["day","noon","night","midnight"]],
  weather:[["clear","rain","thunder"]],
  whitelist:[["add","remove","on","off","list","reload"],P],
  gamerule:[["keep_inventory","players_sleeping_percentage","advance_time","advance_weather","spawn_mobs","spawn_monsters","mob_griefing","fire_spread_radius_around_player","spawn_phantoms","immediate_respawn","natural_health_regeneration","show_advancement_messages","show_death_messages","respawn_radius","random_tick_speed","pvp","locator_bar"],["true","false"]],
  locate:[["structure","biome","poi"]],
  worldborder:[["get","set","add","center","damage","warning"]],
  tick:[["query","rate","freeze","unfreeze","step","sprint"]],
};
function players(){return [...new Set([...(cur&&cur.players?cur.players.list:[]),...known,"@a","@p","@r","@s"])];}
function suggest(){
  const box=$("sugg");box.innerHTML="";matches=[];mi=0;
  const v=$("cmd").value;
  if($("chat").checked||!v||document.activeElement!==$("cmd"))return;
  const parts=v.replace(/^\//,"").split(" ");
  const i=parts.length-1,word=parts[i].toLowerCase();
  let opts=[];
  if(i===0)opts=Object.keys(grammar);
  else{const g=grammar[parts[0].toLowerCase()];const slot=g&&g[i-1];opts=slot===P?players():Array.isArray(slot)?slot:[];}
  matches=opts.filter((o)=>o.toLowerCase().startsWith(word)&&o.toLowerCase()!==word).slice(0,10);
  matches.forEach((m,k)=>{const c=el("span",k===0?"on":"",m);c.onmousedown=(e)=>{e.preventDefault();accept(m);};box.append(c);});
  if(matches.length)box.append(el("em",null,"tab"));
}
function accept(m){
  const c=$("cmd");
  const parts=c.value.split(" ");
  parts[parts.length-1]=(parts.length===1&&c.value.startsWith("/")?"/":"")+m;
  c.value=parts.join(" ")+" ";
  c.focus();suggest();
}
$("cmd").oninput=suggest;
$("cmd").onfocus=suggest;
$("cmd").onblur=()=>setTimeout(()=>{if(document.activeElement!==$("cmd"))$("sugg").innerHTML="";},100);
$("cmd").onkeydown=(e)=>{
  if(e.key==="Tab"){
    e.preventDefault();
    if(matches.length)accept(matches[0]);
    return;
  }
  if(e.key==="Escape"){$("cmd").blur();return;}
  if(e.key==="ArrowUp"&&hi>0){$("cmd").value=hist[--hi];e.preventDefault();suggest();return;}
  if(e.key==="ArrowDown"){hi=Math.min(hist.length,hi+1);$("cmd").value=hist[hi]??"";e.preventDefault();suggest();return;}
  if(e.key!=="Enter"||!sel)return;
  let v=$("cmd").value.trim();if(!v)return;
  if(hist[hist.length-1]!==v)hist.push(v);
  hi=hist.length;$("cmd").value="";$("sugg").innerHTML="";matches=[];
  $("follow").checked=true;
  if($("chat").checked)v="say "+v;
  send(v);
};
const kindPaths={mod:"/mods",datapack:"/mods/datapacks",pack:"/mods/resourcepack"};
const base="/"+encodeURIComponent(sel);
function tabPath(){return base+(tab==="console"?"":tab==="mods"?kindPaths[kind]:"/"+tab);}
function setUrl(push){
  const p=tabPath();
  document.title=tab==="console"?sel:sel+" · "+(tab==="mods"?{mod:"mods",datapack:"datapacks",pack:"resource pack"}[kind]:tab);
  if(location.pathname!==p)history[push?"pushState":"replaceState"](null,"",p);
}
function showTab(name,fromUrl){
  if(tab==="settings"&&propsDirty&&name!=="settings"&&!confirm("discard unsaved settings?"))return false;
  tab=name;
  document.querySelectorAll("[data-tab]").forEach((x)=>x.classList.toggle("on",x.dataset.tab===name));
  $("more").classList.toggle("on",!!document.querySelector("#sheet [data-tab='"+name+"']"));
  $("sheet").hidden=true;
  document.querySelectorAll("[data-pane]").forEach((x)=>x.hidden=x.dataset.pane!==tab);
  setUrl(!fromUrl);
  loadTab();
  if(tab==="console")$("log").scrollTop=$("log").scrollHeight;
  return true;
}
function fromUrl(){
  const seg=location.pathname.split("/").filter(Boolean).slice(1);
  const names=[...document.querySelectorAll("[data-tab]")].map((a)=>a.dataset.tab);
  const t=names.includes(seg[0])?seg[0]:"console";
  if(t==="mods")setKind(Object.keys(kindPaths).find((k)=>kindPaths[k]==="/mods"+(seg[1]?"/"+seg[1]:""))||"mod");
  if(!showTab(t,true))setUrl(true);
}
document.querySelectorAll("[data-tab]").forEach((a)=>a.onclick=(e)=>{
  if(e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;
  e.preventDefault();
  if(tab!==a.dataset.tab)showTab(a.dataset.tab);
});
window.addEventListener("popstate",fromUrl);
$("more").onclick=()=>{$("sheet").hidden=!$("sheet").hidden;};
$("sheet").onclick=(e)=>{if(e.target===$("sheet"))$("sheet").hidden=true;};
$("stheme").onclick=()=>{$("theme").click();$("stheme").textContent=$("theme").title;};
$("stheme").textContent=$("theme").title;
document.addEventListener("keydown",(e)=>{
  const t=e.target;
  const typing=t instanceof HTMLInputElement||t instanceof HTMLTextAreaElement||t instanceof HTMLSelectElement;
  if(e.key==="Escape"&&!$("modal").hidden){closeModal();return;}
  if(typing){if(e.key==="Escape")t.blur();return;}
  if(e.ctrlKey||e.metaKey||e.altKey||!sel)return;
  if(e.key==="/"){e.preventDefault();if(tab!=="console"&&!showTab("console"))return;$("cmd").focus();return;}
  const tabs=[...document.querySelectorAll(".tabs [data-tab]")];
  const n=Number(e.key);
  if(n>=1&&n<=tabs.length){e.preventDefault();showTab(tabs[n-1].dataset.tab);}
});
async function act(action,player,extra){
  await post(sel+"/player",{action,player,extra});
  toast(action+(player?" "+player:"")+" sent","ok");
  setTimeout(loadPlayers,900);
}
function addForm(ph,label,fn){
  const w=el("span","inline");
  const i=el("input","f");i.placeholder=ph;i.spellcheck=false;i.autocomplete="off";
  const go=async()=>{
    const v=i.value.trim();
    if(!/^[A-Za-z0-9_]{1,16}$/.test(v)){toast("not a valid player name","err");return;}
    await fn(v);i.value="";
  };
  i.onkeydown=(e)=>{if(e.key==="Enter")go().catch((x)=>toast(x.message,"err"));};
  w.append(i,btn(label,go));
  return w;
}
function prow(name,...buttons){
  const r=el("div");
  const n=el("span","n");n.append(plink(name));
  r.append(head(name),n,...buttons);
  return r;
}
async function loadPlayers(){
  lastPlayers=Date.now();
  const box=$("players");
  let d;
  try{d=await (await api(sel+"/players")).json();}catch(e){box.textContent=e.message;return;}
  known=d.known;
  if(!cur){setTimeout(loadPlayers,300);return;}
  const live=cur.state==="active";
  box.innerHTML="";
  const sec=(title,extra)=>{const h=el("div","sec");h.append(el("h2",null,title));if(extra)h.append(extra);box.append(h);const r=el("div","rows");box.append(r);return r;};
  if(!live)box.append(el("div","note","offline, start to change"));
  const p=cur&&cur.players;
  const on=sec("online"+(p?" · "+p.online+"/"+p.max:""));
  if(!p||!p.list.length)on.append(el("div","empty",p?"nobody online":"server is offline"));
  else for(const n of p.list){
    on.append(prow(n,
      btn(d.ops.includes(n)?"deop":"op",()=>act(d.ops.includes(n)?"deop":"op",n)),
      btn("kick",()=>confirm("kick "+n+"?")&&act("kick",n),"danger"),
      btn("ban",()=>{const r=prompt("ban "+n+"? reason (optional)");return r!==null&&act("ban",n,r);},"danger")));
  }
  const wlt=btn(d.whitelist.enabled?"on":"off",()=>act("whitelist","",d.whitelist.enabled?"off":"on"),d.whitelist.enabled?"on":"");
  wlt.title=d.whitelist.enabled?"only listed players can join":"anyone can join";
  const wlh=el("span","inline");
  wlh.append(wlt,addForm("player","add",(v)=>act("allow",v)));
  const wl=sec("whitelist",wlh);
  if(!d.whitelist.list.length)wl.append(el("div","empty","nobody whitelisted"));
  for(const n of d.whitelist.list)wl.append(prow(n,btn("remove",()=>act("disallow",n),"danger")));
  const ops=sec("operators",addForm("player","op",(v)=>act("op",v)));
  if(!d.ops.length)ops.append(el("div","empty","no operators"));
  for(const n of d.ops)ops.append(prow(n,btn("deop",()=>act("deop",n))));
  const bans=sec("banned",addForm("player","ban",(v)=>act("ban",v)));
  if(!d.bans.length)bans.append(el("div","empty","nobody banned"));
  for(const b of d.bans){
    const r=prow(b.name,btn("pardon",()=>act("pardon",b.name)));
    if(b.reason&&b.reason!=="Banned by an operator.")r.querySelector(".n").append(el("small",null,b.reason));
    bans.append(r);
  }
  box.querySelectorAll("button,input").forEach((x)=>{if(!live)x.disabled=true;});
}
async function loadActivity(){
  const box=$("activity");
  let list;
  try{list=await (await api(sel+"/activity")).json();}catch(e){box.textContent=e.message;return;}
  box.innerHTML="";
  if(!list.length){box.append(el("div","empty","nothing in the last 7 days"));return;}
  const labels={join:"join",leave:"leave",death:"death",advancement:"advancement",ban:"ban",pardon:"pardon",kick:"kick",op:"op",deop:"deop"};
  for(const a of list){
    const r=el("div");
    const n=el("span","n");n.append(plink(a.player),document.createTextNode(" "));
    n.append(document.createTextNode(a.type==="advancement"?"made the advancement ["+a.text+"]":a.text));
    const d=el("span","d t",ago(a.t)+" ago");d.title=new Date(a.t).toLocaleString();
    r.append(head(a.player),n,el("span","tag "+a.type,labels[a.type]),d);
    box.append(r);
  }
}
let searchTimer=null,installed=[],kind="mod";
const kq=()=>"kind="+kind;
const noun=(n)=>(kind==="mod"?"mod":"datapack")+(n===1?"":"s");
function markChanged(){modsChanged[sel+kind]=true;showChanged();}
function showChanged(){
  const c=!!modsChanged[sel+kind];
  $("mrestart").hidden=!c;
  $("mrestart").textContent=kind==="mod"?"restart to apply":"reload or restart to apply";
  $("mreload").hidden=!(c&&kind==="datapack");
}
$("mreload").onclick=async()=>{
  try{await post(sel+"/command","reload");toast("reloading datapacks","ok");modsChanged[sel+kind]=false;showChanged();}
  catch(e){toast(e.message,"err");}
};
function setKind(k){
  if(kind===k)return false;
  kind=k;
  document.querySelectorAll("[data-k]").forEach((x)=>x.classList.toggle("on",x.dataset.k===k));
  $("modview").hidden=kind==="pack";
  $("packview").hidden=kind!=="pack";
  $("minstalled").innerHTML="";$("mall").innerHTML="";$("mcount").textContent="";
  if(kind==="pack"){$("pcurrent").innerHTML="";$("pstat").textContent="loading…";return true;}
  $("msearch").placeholder="search modrinth "+noun(2);
  $("mresults").innerHTML="";$("mnote").textContent="";
  return true;
}
document.querySelectorAll("[data-k]").forEach((b)=>b.onclick=()=>{
  if(!setKind(b.dataset.k))return;
  setUrl(true);
  if(sel)kind==="pack"?loadPack():loadMods();
});
function restartOk(what){
  if(!cur||cur.state!=="active")return true;
  const n=cur.players&&cur.players.online;
  return confirm(what+" restarts "+sel+"."+(n?" "+n+" player(s) will be disconnected.":"")+" continue?");
}
function applied(r,msg){
  toast(msg+(r&&r.restarted?", server restarting":""),"ok");
  if(r&&r.restarted){pending="restart";pendingAt=Date.now()-1000;}
}
async function loadPack(){
  let p;
  try{p=await (await api(sel+"/pack")).json();}catch(e){$("pstat").textContent=e.message;return;}
  if(kind!=="pack")return;
  $("pstat").textContent="";
  const box=$("pcurrent");box.innerHTML="";
  $("preq").checked=p.required;$("pprompt").value=p.prompt;
  if(!p.url){
    box.append(el("div","empty","no server pack"));
    $("pstat").textContent="";
  }else{
    const m=p.meta;
    const r=el("div");
    const n=el("span","n",m?m.title:"external pack");
    n.append(el("small",null,(m&&m.version?m.version+" · ":"")+(m?mbs(m.size)+" · ":"")+p.url));
    r.append(img(m&&m.icon),n,btn("remove",async()=>{
      if(!restartOk("removing the pack"))return;
      await api(sel+"/pack",{method:"DELETE"});
      applied({restarted:cur&&cur.state==="active"},"pack removed");
      loadPack();
    },"danger"));
    box.append(r);
    $("pstat").textContent=p.required?"required":"optional";
  }
}
$("psave").onclick=async()=>{
  if(!restartOk("saving"))return;
  $("psave").disabled=true;$("psave").textContent="saving…";
  try{
    const r=await (await post(sel+"/pack/settings",{required:$("preq").checked,prompt:$("pprompt").value})).json();
    applied(r,"pack settings saved");loadPack();
  }catch(e){toast(e.message,"err");}
  $("psave").disabled=false;$("psave").textContent="save";
};
$("pupload").onclick=()=>$("pfile").click();
$("pfile").onchange=async()=>{
  const f=$("pfile").files[0];$("pfile").value="";
  if(!f)return;
  if(!/.zip$/i.test(f.name)){toast("pick a .zip file","err");return;}
  if(f.size>250*1048576){toast("pack is larger than 250 MB","err");return;}
  if(!restartOk("using a new pack"))return;
  const b=$("pupload");b.disabled=true;b.textContent="uploading "+mbs(f.size)+"…";
  try{
    const r=await (await api(sel+"/pack/upload?name="+encodeURIComponent(f.name),{method:"POST",body:f})).json();
    applied(r,"pack uploaded and active");loadPack();
  }catch(e){toast("upload failed: "+e.message,"err");}
  b.disabled=false;b.textContent="upload zip";
};
let psTimer=null;
async function packSearch(){
  const q=$("psearch").value.trim();
  const box=$("presults");
  if(!q){box.innerHTML="";$("psnote").textContent="";return;}
  $("psnote").textContent="searching…";
  let hits;
  try{hits=await (await api(sel+"/pack/search?q="+encodeURIComponent(q))).json();}catch(e){$("psnote").textContent=e.message;return;}
  if($("psearch").value.trim()!==q)return;
  $("psnote").textContent=hits.length?hits.length+" results for "+(cur?cur.version:""):"nothing found for "+(cur?cur.version:"");
  box.innerHTML="";
  for(const h of hits){
    const r=el("div");
    const n=el("span","n");
    const a=el("a",null,h.title);a.href="https://modrinth.com/resourcepack/"+h.slug;a.target="_blank";a.rel="noopener";
    n.append(a,el("small",null,h.description));
    r.append(img(h.icon),n,el("span","d num",num(h.downloads)),btn("use",async(b)=>{
      if(!restartOk("using a new pack"))return;
      b.textContent="downloading…";
      const res=await (await post(sel+"/pack/install",{project:h.project})).json();
      applied(res,h.title+" is now the server pack");loadPack();
    }));
    box.append(r);
  }
}
$("psearch").oninput=()=>{clearTimeout(psTimer);psTimer=setTimeout(packSearch,400);};
async function update(m){
  const res=await (await post(sel+"/mods/install?"+kq(),{project:m.project})).json();
  markChanged();
  return res;
}
async function loadMods(){
  const k=kind;
  $("mcount").textContent="loading…";
  showChanged();
  let list;
  try{list=await (await api(sel+"/mods?"+kq())).json();}catch(e){$("mcount").textContent=e.message;return;}
  if(k!==kind)return;
  installed=list;
  const box=$("minstalled");box.innerHTML="";
  const outdated=installed.filter((m)=>m.update);
  $("mcount").textContent=installed.length+" "+noun(installed.length)+(outdated.length?" · "+outdated.length+" update"+(outdated.length===1?"":"s"):"");
  $("mall").innerHTML="";
  if(outdated.length>1)$("mall").append(btn("update all",async(b)=>{
    for(const [i,m] of outdated.entries()){b.textContent="updating "+(i+1)+"/"+outdated.length+"…";await update(m);}
    toast("updated "+outdated.length+" "+noun(2),"ok");loadMods();
  }));
  if(!installed.length)box.append(el("div","empty","no "+noun(2)+" yet, search above to add some"));
  for(const m of installed){
    const r=el("div");
    const n=el("span","n",m.title||m.file);
    n.append(el("small",null,(m.version?m.version+" · ":"")+m.file+" · "+mbs(m.size)));
    r.append(img(m.icon),n);
    if(m.update){
      const u=btn("update",async()=>{await update(m);toast("updated "+(m.title||m.file)+" to "+m.update,"ok");loadMods();});
      u.title="new version: "+m.update;u.classList.add("on");
      r.append(u);
    }
    r.append(btn("remove",async()=>{
      if(!confirm("remove "+(m.title||m.file)+"?"))return;
      await api(sel+"/mods/"+encodeURIComponent(m.file)+"?"+kq(),{method:"DELETE"});
      toast("removed "+(m.title||m.file),"ok");markChanged();
      loadMods();
    },"danger"));
    box.append(r);
  }
  if($("msearch").value.trim())doSearch();
}
async function doSearch(){
  const q=$("msearch").value.trim();
  const box=$("mresults");
  if(!q){box.innerHTML="";$("mnote").textContent="";return;}
  $("mnote").textContent="searching…";
  let hits;
  const k=kind;
  try{hits=await (await api(sel+"/mods/search?"+kq()+"&q="+encodeURIComponent(q))).json();}catch(e){$("mnote").textContent=e.message;return;}
  if($("msearch").value.trim()!==q||k!==kind)return;
  $("mnote").textContent=hits.length?hits.length+" results for "+(cur?cur.version:""):"nothing found for "+(cur?cur.version:"");
  box.innerHTML="";
  for(const h of hits){
    const r=el("div");
    const n=el("span","n");
    const a=el("a",null,h.title);a.href="https://modrinth.com/"+(kind==="mod"?"mod":"datapack")+"/"+h.slug;a.target="_blank";a.rel="noopener";
    n.append(a,el("small",null,h.description));
    const has=installed.some((m)=>m.project===h.project);
    r.append(img(h.icon),n,el("span","d num",num(h.downloads)));
    if(has)r.append(el("span","d","installed"));
    else r.append(btn("install",async(b)=>{
      b.textContent="installing…";
      const res=await (await post(sel+"/mods/install?"+kq(),{project:h.project})).json();
      toast("installed "+res.map((x)=>x.file).join(", "),"ok");
      markChanged();
      loadMods();
    }));
    box.append(r);
  }
}
$("msearch").oninput=()=>{clearTimeout(searchTimer);searchTimer=setTimeout(doSearch,400);};
function chart(title,pts,fmt,max){
  const w=el("div","chart");
  const lbl=el("div","lbl");
  const last=pts.length?pts[pts.length-1][1]:0;
  const peak=pts.reduce((m,p)=>Math.max(m,p[1]),0);
  lbl.append(el("span",null,title+" · "+fmt(last)),el("span",null,"24h peak "+fmt(peak)));
  const ns="http://www.w3.org/2000/svg";
  const svg=document.createElementNS(ns,"svg");
  svg.setAttribute("viewBox","0 0 1000 100");svg.setAttribute("preserveAspectRatio","none");
  const start=Date.now()-range,top=Math.max(max||0,peak)*1.1||1;
  const xy=pts.map(([t,v])=>[((t-start)/range*1000).toFixed(1),(100-v/top*96).toFixed(1)]);
  if(xy.length>1){
    const d="M"+xy.map((p)=>p.join(",")).join("L");
    const l=document.createElementNS(ns,"path");l.setAttribute("d",d);l.setAttribute("class","l");
    const a=document.createElementNS(ns,"path");a.setAttribute("d",d+"L"+xy[xy.length-1][0]+",100L"+xy[0][0]+",100Z");a.setAttribute("class","a");
    svg.append(a,l);
  }
  w.append(lbl,svg);
  if(xy.length<2)w.append(el("div","empty","collecting data, one point per minute"));
  return w;
}
async function loadStats(){
  let h;
  try{h=await (await api(sel+"/history")).json();}catch(e){$("charts").textContent=e.message;return;}
  const from=Date.now()-range;
  const pts=h.filter((p)=>p[0]>=from);
  const c=$("charts");c.innerHTML="";
  c.append(
    chart("players",pts.map((p)=>[p[0],p[1]]),(v)=>String(v),cur&&cur.players?cur.players.max/4:4),
    chart("memory",pts.map((p)=>[p[0],p[2]]),gb,cur?cur.limit:0),
    chart("cpu",pts.map((p)=>[p[0],p[3]]),(v)=>v+"%",100));
  loadBoard();
}
const dist=(cm)=>cm>=100000?(cm/100000).toFixed(1)+" km":Math.round(cm/100)+" m";
const hearts=(h)=>num(Math.round(h/2))+" ♥";
const pretty=(k)=>k.replace(/_/g," ");
const metrics=[["playtime","playtime",dur],["mobKills","mob kills",num],["deaths","deaths",num],["distance","distance travelled",dist],["mined","blocks mined",num],["crafted","items crafted",num],["playerKills","player kills",num],["damageDealt","damage dealt",hearts],["damageTaken","damage taken",hearts],["jumps","jumps",num],["fish","fish caught",num],["bred","animals bred",num],["trades","villager trades",num],["enchants","items enchanted",num],["sleeps","nights slept",num]];
for(const[k,l]of metrics){const o=el("option",null,l);o.value=k;$("lbby").append(o);}
try{$("lbby").value=localStorage.getItem("lbby")||"playtime";}catch{}
$("lbby").onchange=()=>{try{localStorage.setItem("lbby",$("lbby").value);}catch{}loadBoard();};
async function loadBoard(){
  const box=$("lb");
  let list;
  try{list=await (await api(sel+"/leaderboard")).json();}catch(e){box.textContent=e.message;return;}
  const [k,,fmt]=metrics.find((m)=>m[0]===$("lbby").value)||metrics[0];
  box.innerHTML="";
  list=list.filter((p)=>p[k]>0).sort((a,b)=>b[k]-a[k]);
  if(!list.length){box.append(el("div","empty","no stats yet, saved on leave and autosave"));return;}
  list.forEach((p,i)=>{
    const r=el("div");
    const n=el("span","n");n.append(plink(p.player));
    r.append(el("span","d",String(i+1)),head(p.player),n,el("span","d num",fmt(p[k])));
    box.append(r);
  });
}
async function loadTasks(){
  let t;
  try{t=await (await api(sel+"/tasks")).json();}catch(e){$("tasks").textContent=e.message;return;}
  const box=$("tasks");
  if(box.querySelector(".busy"))return;
  box.innerHTML="";
  const r1=el("div");
  const n1=el("span","n","restart with countdown");
  const restarting=t.restart.state==="active"||t.restart.state==="activating";
  n1.append(el("small",null,restarting?"counting down, players were warned":t.restart.at?"daily at "+t.restart.at+(t.restart.next?" · next in "+dur(t.restart.next-Date.now()):""):"not scheduled · 5 min warning"));
  const rb=restarting
    ?btn("cancel",async()=>{await post(sel+"/restart/cancel");toast("restart cancelled","ok");loadTasks();},"danger")
    :btn("run now",async()=>{if(!confirm("restart "+sel+" in 5 minutes?"))return;await post(sel+"/restart/countdown");toast("countdown started, players are warned","ok");loadTasks();});
  if(!restarting&&cur&&cur.state!=="active")rb.disabled=true;
  r1.append(n1,rb);
  const r2=el("div");
  const n2=el("span","n","backup");
  const busy=t.backup.state==="activating"||t.backup.state==="active";
  n2.append(el("small",null,busy?"running…":"daily at "+t.backup.at+(t.backup.next?" · next in "+dur(t.backup.next-Date.now()):"")+(t.backup.result&&t.backup.result!=="success"?" · last run failed":"")));
  const bb=btn(busy?"backing up…":"back up now",async()=>{await post(sel+"/backup");toast("backup started");lastBackup="activating";loadTasks();});
  bb.disabled=busy;
  r2.append(n2,bb);
  box.append(r1,r2);
  if(lastBackup&&!busy&&lastBackup!==t.backup.state){
    if(t.backup.result==="success")toast("backup finished","ok");else toast("backup failed: "+t.backup.result,"err");
    loadBackups();
  }
  lastBackup=t.backup.state;
}
async function loadBackups(){
  const box=$("backups");
  try{
    const list=await (await api(sel+"/backups")).json();
    box.innerHTML="";
    if(!list.length){box.append(el("div","empty","no backups yet"));return;}
    for(const b of list){
      const r=el("div");
      const a=el("a","btn","download");a.href="/api/"+sel+"/backups/"+b.file;
      const n=el("span","n",short(b.time));n.append(el("small",null,mbs(b.size)+" · "+ago(b.time)+" ago"));r.append(n,a,btn("restore",async()=>{
        const who=cur&&cur.players&&cur.players.online?" "+cur.players.online+" player(s) will be disconnected.":"";
        if(!confirm("restore the world from "+new Date(b.time).toLocaleString()+"? the current world is kept as a copy"+who))return;
        await post(sel+"/restore",{file:b.file});
        toast("restoring…","ok");
        pending="restart";pendingAt=Date.now()-1000;
      },"danger"));
      box.append(r);
    }
  }catch(e){box.textContent=e.message;}
}
const fields=[
  ["motd","message of the day","text",true],
  ["difficulty","difficulty",["peaceful","easy","normal","hard"]],
  ["gamemode","game mode",modes],
  ["max-players","max players","number"],
  ["view-distance","view distance","number"],
  ["simulation-distance","simulation distance","number"],
  ["spawn-protection","spawn protection","number"],
  ["pvp","pvp","bool"],
  ["allow-flight","allow flight","bool"],
  ["hardcore","hardcore","bool"],
];
function getProp(txt,k){const l=txt.split("\n").find((x)=>x.startsWith(k+"="));return l==null?null:l.slice(k.length+1);}
function setProp(txt,k,v){
  const lines=txt.split("\n");
  const i=lines.findIndex((x)=>x.startsWith(k+"="));
  if(i>=0)lines[i]=k+"="+v;
  else{if(lines[lines.length-1]==="")lines.pop();lines.push(k+"="+v,"");}
  return lines.join("\n");
}
function renderForm(){
  const f=$("pform");f.innerHTML="";
  const txt=$("props").value;
  for(const [k,label,type,wide] of fields){
    const v=getProp(txt,k);
    let input;
    const l=el("label",type==="bool"?"b":wide?"wide":"");
    if(type==="bool"){
      input=el("input");input.type="checkbox";input.checked=v==="true";
      l.append(input,document.createTextNode(label));
    }else{
      if(Array.isArray(type)){input=el("select","f");for(const o of type){const op=el("option",null,o);op.value=o;input.append(op);}input.value=v??type[0];}
      else{input=el("input","f");input.type=type;input.value=v??"";if(type==="number")input.min="0";}
      l.append(document.createTextNode(label),input);
    }
    input.onchange=input.oninput=()=>{
      $("props").value=setProp($("props").value,k,type==="bool"?String(input.checked):input.value);
      propsDirty=true;$("pstate").textContent="unsaved changes";
    };
    f.append(l);
  }
}
let worldBusy=null,worldTimer=null,worldData=null;
const worldLabels={reset:"creating a new world",nether:"resetting the nether",end:"resetting the end",import:"importing the uploaded world"};
const worldDone={reset:"new world created",nether:"the nether was reset",end:"the end was reset",import:"world imported"};
function sendXhr(path,file,onp){
  return new Promise((res,rej)=>{
    const x=new XMLHttpRequest();
    x.open("POST","/api/"+path);
    x.upload.onprogress=(e)=>{if(e.lengthComputable)onp(e.loaded/e.total);};
    x.onload=()=>x.status<300?res():rej(new Error(x.responseText||x.statusText));
    x.onerror=()=>rej(new Error("connection lost"));
    x.send(file);
  });
}
async function loadWorld(){
  clearTimeout(worldTimer);
  const s=sel;
  let w;
  try{w=await (await api(s+"/world")).json();}catch(e){$("winfo").textContent=e.message;return;}
  if(s!==sel||tab!=="world")return;
  worldData=w;
  if(worldBusy&&!w.busy&&w.last){toast(w.last.ok?worldDone[w.last.action]:"failed: "+(w.last.message||w.last.action),w.last.ok?"ok":"err");}
  worldBusy=w.busy;
  if(w.busy)worldTimer=setTimeout(loadWorld,2000);
  const note=$("wnote");
  note.hidden=!w.busy&&!(w.last&&!w.last.ok);
  note.textContent=w.busy?worldLabels[w.busy]+"… the server is stopped":w.last&&!w.last.ok?"last task failed: "+(w.last.message||w.last.action)+" · "+ago(w.last.t)+" ago":"";
  const live=cur&&cur.state==="active";
  const kv=$("winfo");kv.innerHTML="";
  const cell=(k,v,copy)=>{const d=el("div",copy?"c":null);d.append(el("span",null,k),document.createTextNode(v));if(copy){d.title="copy";d.onclick=()=>toast(copyText(v)?"copied":"could not copy",copyText.ok?"ok":"err");}kv.append(d);return d;};
  if(!w.exists)cell("world","created on first start");
  else{
    cell("world",w.name||w.level);
    if(w.version)cell("version",w.version);
    if(w.seed)cell("seed",w.seed,true).classList.add("wide");
    cell("difficulty",(w.difficulty||"–")+(w.hardcore?" · hardcore":""));
    if(w.day)cell("day",String(w.day));
    if(w.spawn)cell("spawn",w.spawn.join(" "),true);
    if(w.lastPlayed)cell("last saved",ago(w.lastPlayed)+" ago");
  }
  const total=Object.values(w.sizes).reduce((a,b)=>a+b,0);
  $("wtotal").textContent=total?mbs(total):"";
  const sz=$("wsize");sz.innerHTML="";
  const order=["overworld","nether","end","players","datapacks","other"];
  const kinds=order.filter((k)=>w.sizes[k]);
  if(!kinds.length)sz.append(el("div","empty","nothing on disk yet"));
  for(const k of kinds){const r=el("div");r.append(el("span","n",k),el("span","d num",mbs(w.sizes[k])));sz.append(r);}
  const q=$("wquick");q.innerHTML="";
  const cmd=(c,msg)=>btn(msg,async()=>{await post(sel+"/command",c);toast(c,"ok");});
  const qrow=(label,...b)=>{const r=el("div");const g=el("span","grp");g.append(...b);r.append(el("span","n",label),g);q.append(r);};
  if(!live)q.append(el("div","empty","start the server to use these"));
  else{
    qrow("time",cmd("time set day","day"),cmd("time set noon","noon"),cmd("time set night","night"),cmd("time set midnight","midnight"));
    qrow("weather",cmd("weather clear","clear"),cmd("weather rain","rain"),cmd("weather thunder","thunder"));
    qrow("difficulty",...["peaceful","easy","normal","hard"].map((d)=>{const b=cmd("difficulty "+d,d);if(w.difficulty===d)b.classList.add("on");return b;}));
    qrow("save",cmd("save-all","save now"));
  }
  renderRules();
  const m=$("wmanage");m.innerHTML="";
  const mrow=(title,...x)=>{const r=el("div");r.append(el("span","n",title),...x);m.append(r);return r;};
  const dl=btn("download",async(b)=>{
    const before=new Set((await (await api(sel+"/backups")).json()).map((x)=>x.file));
    await post(sel+"/backup");
    b.textContent="backing up…";
    try{
      for(let i=0;i<300;i++){
        await new Promise((r)=>setTimeout(r,2000));
        const n=(await (await api(sel+"/backups")).json()).find((x)=>!before.has(x.file));
        if(n){location.href="/api/"+sel+"/backups/"+n.file;toast("download started","ok");return;}
      }
      throw new Error("the backup took too long");
    }finally{b.textContent="download";}
  });
  mrow("download the world",dl);
  const up=btn("upload",async()=>$("wfile").click());
  mrow("upload a world",up);
  const ask=(what)=>{const n=cur&&cur.players&&cur.players.online;return confirm(what+"? a backup is made first"+(live?", the server restarts"+(n?" and "+n+" player(s) are disconnected":""):"")+".");};
  const act_=(action,extra)=>async()=>{await post(sel+"/world/action",{action,...extra});worldBusy=action;loadWorld();};
  mrow("reset the nether",btn("reset",async()=>{if(ask("reset the nether"))await act_("nether")();},"danger"));
  mrow("reset the end",btn("reset",async()=>{if(ask("reset the end"))await act_("end")();},"danger"));
  const seed=el("input","f");seed.placeholder="seed, empty for random";seed.value=w.seedProp;seed.maxLength=64;
  const type=el("select","f");
  for(const [v,l] of [["minecraft:normal","normal"],["minecraft:flat","flat"],["minecraft:large_biomes","large biomes"],["minecraft:amplified","amplified"]]){const o=el("option",null,l);o.value=v;type.append(o);}
  type.value=w.typeProp;
  const pick=el("select","f"),preset=el("input","f wide");
  preset.placeholder="layers;biome";preset.maxLength=2000;preset.value=w.presetProp||flatPresets[0][1];
  for(const [l,v] of flatPresets){const o=el("option",null,l);o.value=v;pick.append(o);}
  const custom=el("option",null,"custom");custom.value="";pick.append(custom);
  const sync=()=>{pick.value=flatPresets.some(([,v])=>v===preset.value)?preset.value:"";};
  pick.onchange=()=>{if(pick.value)preset.value=pick.value;else preset.focus();};
  preset.oninput=sync;sync();
  mrow("new world",seed,type,btn("create",async()=>{if(ask("replace this world"))await act_("reset",{seed:seed.value,type:type.value,preset:preset.value})();},"danger"));
  const flatRow=mrow("flat layers",pick,preset);
  const showFlat=()=>{flatRow.hidden=type.value!=="minecraft:flat";};
  type.addEventListener("change",showFlat);showFlat();
  m.querySelectorAll("button,input,select").forEach((x)=>{if(w.busy)x.disabled=true;});
}
const flatPresets=[["classic","minecraft:bedrock,2*minecraft:dirt,minecraft:grass_block;minecraft:plains"],["tunnelers dream","minecraft:bedrock,230*minecraft:stone,5*minecraft:dirt,minecraft:grass_block;minecraft:windswept_hills"],["water world","minecraft:bedrock,5*minecraft:stone,5*minecraft:dirt,5*minecraft:sand,90*minecraft:water;minecraft:deep_ocean"],["snowy kingdom","minecraft:bedrock,59*minecraft:stone,3*minecraft:dirt,minecraft:grass_block,minecraft:snow;minecraft:snowy_plains"],["desert","minecraft:bedrock,3*minecraft:stone,52*minecraft:sandstone,8*minecraft:sand;minecraft:desert"],["redstone ready","minecraft:bedrock,3*minecraft:stone,116*minecraft:sandstone;minecraft:desert"],["the void","minecraft:air;minecraft:the_void"]];
const ruleDefaults={"spawn_wandering_traders":true,"block_drops":true,"reduced_debug_info":false,"show_death_messages":true,"spawn_monsters":true,"spawner_blocks_work":true,"tnt_explodes":true,"player_movement_check":true,"immediate_respawn":false,"spread_vines":true,"block_explosion_drop_decay":true,"max_entity_cramming":24,"forgive_dead_players":true,"fall_damage":true,"send_command_feedback":true,"global_sound_events":true,"elytra_movement_check":true,"fire_spread_radius_around_player":128,"freeze_damage":true,"mob_explosion_drop_decay":true,"natural_health_regeneration":true,"players_nether_portal_default_delay":80,"mob_drops":true,"log_admin_commands":true,"mob_griefing":true,"pvp":true,"spawn_mobs":true,"spectators_generate_chunks":true,"players_sleeping_percentage":100,"players_nether_portal_creative_delay":0,"max_command_sequence_length":65536,"advance_weather":true,"max_block_modifications":32768,"max_command_forks":65536,"drowning_damage":true,"locator_bar":true,"command_block_output":true,"show_advancement_messages":true,"respawn_radius":10,"raids":true,"spawn_phantoms":true,"max_snow_accumulation_height":1,"limited_crafting":false,"allow_entering_nether_using_portals":true,"lava_source_conversion":false,"tnt_explosion_drop_decay":false,"keep_inventory":false,"universal_anger":false,"spawn_patrols":true,"random_tick_speed":3,"fire_damage":true,"entity_drops":true,"advance_time":true,"command_blocks_work":true,"spawn_wardens":true,"projectiles_can_break_blocks":true,"water_source_conversion":true,"ender_pearls_vanish_on_death":true};
function ruleChanges(){const w=worldData;if(!w||!w.rules)return [];return Object.entries(ruleDefaults).filter(([k,v])=>k in w.rules&&String(w.rules[k])!==String(v));}
function renderRules(){
  const w=worldData,box=$("wrules");box.innerHTML="";
  if(!w)return;
  const live=cur&&cur.state==="active";
  if(!w.rules){box.append(el("div","empty","no game rules in the world file yet"));return;}
  const f=$("wfilter").value.trim().toLowerCase();
  const names=Object.keys(w.rules).sort().filter((k)=>!f||k.toLowerCase().includes(f));
  const ch=ruleChanges();
  $("wdefaults").disabled=!live||!ch.length;
  $("wdefaults").title=ch.length?ch.length+" changed":"all default";
  if(!live)box.append(el("div","note","start the server to change rules"));
  if(!names.length)box.append(el("div","empty","no rule matches"));
  $("wdefaults").onclick=async()=>{
    const ch=ruleChanges();
    if(!ch.length||!confirm("reset "+ch.length+" rule"+(ch.length>1?"s":"")+" to default?"))return;
    for(const [k,v] of ch){await post(sel+"/command","gamerule "+k+" "+v);w.rules[k]=v;}
    toast("rules reset","ok");renderRules();
  };
  const set=async(k,v)=>{await post(sel+"/command","gamerule "+k+" "+v);w.rules[k]=typeof w.rules[k]==="boolean"?v==="true":typeof w.rules[k]==="number"?Number(v):String(v);toast(k+" = "+v,"ok");renderRules();};
  for(const k of names){
    const v=w.rules[k];
    const r=el("div");
    r.append(el("span","n",k.replace(/_/g," ")));
    const bool=v===true||v===false||v==="true"||v==="false";
    if(bool){
      const on=v===true||v==="true"||v===1;
      const b=btn(on?"on":"off",()=>set(k,on?"false":"true"),on?"on":"");
      if(!live)b.disabled=true;
      r.append(b);
    }else{
      const i=el("input","f num");i.value=String(v);i.disabled=!live;
      i.onkeydown=(e)=>{if(e.key==="Enter")i.blur();};
      i.onchange=async()=>{const val=i.value.trim();if(!/^-?d+$/.test(val)){toast("enter a whole number","err");i.value=String(v);return;}try{await set(k,val);}catch(e){toast(e.message,"err");}};
      r.append(i);
    }
    box.append(r);
  }
}
$("wfilter").oninput=renderRules;
$("wfile").onchange=async()=>{
  const f=$("wfile").files[0];$("wfile").value="";
  if(!f)return;
  if(!/.(zip|tar.gz|tgz)$/i.test(f.name)){toast("pick a .zip or .tar.gz file","err");return;}
  const live=cur&&cur.state==="active";
  if(!confirm("replace the current world with "+f.name+"? a backup is made first"+(live?", the server restarts":"")+"."))return;
  const note=$("wnote");note.hidden=false;
  try{
    await sendXhr(sel+"/world/upload",f,(p)=>{note.textContent="uploading "+f.name+" · "+Math.round(p*100)+"% of "+mbs(f.size);});
    worldBusy="import";loadWorld();
  }catch(e){note.hidden=true;toast("upload failed: "+e.message,"err");}
};
async function loadIcons(){
  let d;
  try{d=await (await api(sel+"/icons")).json();}catch(e){$("icur").textContent=e.message;return;}
  const c=$("icur");c.innerHTML="";
  const t=el("div","t");
  const say=(a,b)=>{t.append(document.createTextNode(a),el("small",null,b));};
  if(!d.active)say("no icon",d.live?"shows after restart":"players see the default icon");
  else if(d.live===undefined)say("icon set","shown once the server starts");
  else if(d.live===d.active)say("icon set","shown in the server list");
  else say("new icon set","shown after the next restart");
  c.append(img(d.active?"/api/"+sel+"/icon/"+d.active:null),t);
  if(d.live!==undefined&&(d.live||null)!==d.active)c.append(btn("restart now",async()=>{
    if(!restartOk("showing the new icon"))return;
    await post(sel+"/restart");pending="restart";pendingAt=Date.now()-1000;render();toast("restarting "+sel,"ok");
  }));
  if(d.active)c.append(btn("remove",async()=>{await api(sel+"/icon",{method:"DELETE"});loadIcons();refresh();},"danger"));
  const l=$("ilist");l.innerHTML="";
  for(const i of d.list){
    const w=el("div",i.id===d.active?"on":"");
    w.title=i.id===d.active?"in use":"use this icon";
    w.append(img("/api/"+sel+"/icon/"+i.id));
    if(i.id===d.active)w.append(el("span",null,"in use"));
    else{
      const x=el("a",null,"delete");
      x.onclick=async(e)=>{e.stopPropagation();if(!confirm("delete this icon?"))return;try{await api(sel+"/icon/"+i.id,{method:"DELETE"});loadIcons();}catch(er){toast(er.message,"err");}};
      w.append(x);
      w.onclick=async()=>{try{await post(sel+"/icon/use",{id:i.id});loadIcons();refresh();}catch(er){toast(er.message,"err");}};
    }
    l.append(w);
  }
}
async function toIcon(file){
  const u=URL.createObjectURL(file);
  const b=new Image();b.src=u;
  try{await b.decode();}catch{throw new Error("unsupported image");}finally{URL.revokeObjectURL(u);}
  const side=Math.min(b.naturalWidth,b.naturalHeight);
  const c=document.createElement("canvas");c.width=c.height=64;
  const x=c.getContext("2d");
  x.imageSmoothingEnabled=side>64;x.imageSmoothingQuality="high";
  x.drawImage(b,(b.naturalWidth-side)/2,(b.naturalHeight-side)/2,side,side,0,0,64,64);
  return new Promise((r,j)=>c.toBlob((o)=>o?r(o):j(new Error("could not convert the image")),"image/png"));
}
$("iupload").onclick=()=>$("ifile").click();
$("ifile").onchange=async()=>{
  const f=$("ifile").files[0];$("ifile").value="";
  if(!f)return;
  const b=$("iupload");b.disabled=true;
  try{
    await api(sel+"/icon/upload",{method:"POST",body:await toIcon(f)});
    toast("icon uploaded","ok");loadIcons();refresh();
  }catch(e){toast("upload failed: "+e.message,"err");}
  b.disabled=false;
};
async function loadProps(){
  $("pstate").textContent="loading…";
  try{
    $("props").value=await (await api(sel+"/properties")).text();
    propsDirty=false;$("pstate").textContent="server.properties";
    renderForm();
  }catch(e){$("pstate").textContent=e.message;$("pform").innerHTML="";}
}
$("props").oninput=()=>{propsDirty=true;$("pstate").textContent="unsaved changes";};
$("props").onchange=renderForm;
$("reload").onclick=()=>{if(!propsDirty||confirm("discard unsaved settings?"))loadProps();};
function saveLabel(){
  const up=cur&&cur.state==="active";
  $("save").textContent=up?"save & restart":"save";
  $("save").title=up?"restarts the server":"";
}
$("save").onclick=async()=>{
  const up=cur&&cur.state==="active";
  if(up&&cur.players&&cur.players.online&&!confirm("save and restart "+sel+"? "+cur.players.online+" player(s) will be disconnected"))return;
  $("save").disabled=true;$("save").textContent=up?"restarting…":"saving…";
  try{
    await api(sel+"/properties"+(up?"?apply":""),{method:"PUT",body:$("props").value});
    propsDirty=false;
    $("pstate").textContent=up?"saved, restarting":"saved, applies on next start";
    toast(up?"settings saved, server restarting":"settings saved","ok");
    if(up){pending="restart";pendingAt=Date.now()-1000;}
  }catch(e){toast("save failed: "+e.message,"err");}
  $("save").disabled=false;saveLabel();
};
function openModal(...nodes){
  const b=$("mbody");b.innerHTML="";b.append(...nodes);
  $("modal").hidden=false;
}
function closeModal(){$("modal").hidden=true;}
$("modal").onclick=(e)=>{if(e.target===$("modal"))closeModal();};
$("mclose").onclick=closeModal;
function plink(n){const a=el("a","pl",n);a.onclick=(e)=>{e.preventDefault();openProfile(n);};return a;}
function when(t){return t?new Date(t).toLocaleString()+" · "+ago(t)+" ago":"–";}
async function openProfile(n){
  const top=el("div","mhead");
  const t=el("div","t",n);t.append(el("small",null,"loading…"));
  const im=img("https://mc-heads.net/avatar/"+encodeURIComponent(n)+"/48");
  top.append(im,t);
  openModal(top);
  let p;
  try{p=await (await api(sel+"/profile/"+encodeURIComponent(n))).json();}catch(e){t.lastChild.textContent=e.message;return;}
  t.lastChild.textContent=p.online?"online now":p.last?"last seen "+ago(p.last)+" ago":"never joined";
  const kv=el("div","kv");
  const cell=(k,v)=>{const d=el("div");d.append(el("span",null,k),document.createTextNode(v));kv.append(d);};
  const s=p.stats;
  cell("playtime",s&&s.playtime?dur(s.playtime):p.playtime?dur(p.playtime):"–");
  cell("sessions",String(p.sessions));
  cell("longest session",p.longest?dur(p.longest):"–");
  cell("deaths",String(s?s.deaths:p.deaths));
  cell("advancements",String(p.advancements));
  cell("kicked",String(p.kicks));
  if(s){
    cell("mob kills",num(s.mobKills));
    cell("player kills",num(s.playerKills));
    cell("damage dealt",hearts(s.damageDealt));
    cell("damage taken",hearts(s.damageTaken));
    cell("distance",dist(s.distance));
    cell("jumps",num(s.jumps));
    cell("blocks mined",num(s.mined));
    cell("items crafted",num(s.crafted));
    cell("tools broken",num(s.broken));
    cell("fish caught",num(s.fish));
    cell("animals bred",num(s.bred));
    cell("villager trades",num(s.trades));
    cell("items enchanted",num(s.enchants));
    cell("nights slept",num(s.sleeps));
    cell("alive for",s.sinceDeath?dur(s.sinceDeath):"–");
  }
  const nodes=[top,kv];
  const meta=el("div","rows");
  const row=(k,v)=>{const r=el("div");r.append(el("span","n",k),el("span","d",v));meta.append(r);};
  row("first seen",when(p.first));
  row("last seen",p.online?"now":when(p.last));
  nodes.push(meta);
  if(p.recentDeaths.length){
    const s=el("div","sec");s.append(el("h2",null,"recent deaths"));
    const r=el("div","rows");
    for(const d of p.recentDeaths){const x=el("div");x.append(el("span","n",n+" "+d.text),el("span","d t",ago(d.t)+" ago"));r.append(x);}
    nodes.push(s,r);
  }
  if(p.recentAdvancements.length){
    const s=el("div","sec");s.append(el("h2",null,"recent advancements"));
    const r=el("div","rows");
    for(const d of p.recentAdvancements){const x=el("div");x.append(el("span","n",d.text),el("span","d t",ago(d.t)+" ago"));r.append(x);}
    nodes.push(s,r);
  }
  if(s)for(const[title,list,fmt]of[["travel",s.travel,dist],["most mined",s.topMined,num],["most killed",s.topKilled,num],["killed by",s.killedBy,num],["most crafted",s.topCrafted,num]]){
    if(!list.length)continue;
    const h=el("div","sec");h.append(el("h2",null,title));
    const r=el("div","rows");
    for(const[k,v]of list){const x=el("div");x.append(el("span","n",pretty(k)),el("span","d num",fmt(v)));r.append(x);}
    nodes.push(h,r);
  }
  openModal(...nodes);
}
async function loadCrashes(){
  const box=$("crashes");
  let list;
  try{list=await (await api(sel+"/crashes")).json();}catch(e){box.textContent=e.message;return;}
  box.innerHTML="";
  if(!list.length){box.append(el("div","empty","no crashes, nice"));return;}
  for(const c of list){
    const r=el("div");
    const n=el("span","n",c.startup?"failed to start":c.description||"crash");
    n.append(el("small",null,(c.suspects.length?"suspects: "+c.suspects.join(", ")+" · ":"")+(c.error||c.file||"")));
    const d=el("span","d t",ago(c.time)+" ago");d.title=new Date(c.time).toLocaleString();
    r.append(n,d,btn("view",()=>showCrash(c)));
    box.append(r);
  }
}
function showCrash(c){
  const top=el("div","mhead");
  const t=el("div","t",c.startup?"server failed to start":c.description||"crash report");
  t.append(el("small",null,new Date(c.time).toLocaleString()+(c.file?" · "+c.file:"")));
  top.append(t);
  const nodes=[top];
  if(c.error)nodes.push(el("div","err",c.error));
  if(c.suspects.length){
    const s=el("div","chips");
    for(const x of c.suspects)s.append(el("span",null,x));
    nodes.push(el("div","empty","likely involved"),s);
  }else nodes.push(el("div","empty","no mod named, see below"));
  nodes.push(el("pre",null,c.text));
  openModal(...nodes);
}
addEventListener("beforeunload",(e)=>{if(propsDirty)e.preventDefault();});
document.querySelectorAll("a[data-tab]").forEach((a)=>a.href=base+(a.dataset.tab==="console"?"":"/"+a.dataset.tab));
fromUrl();
connect();loadKnown();
refresh();setInterval(refresh,2000);
document.addEventListener("visibilitychange",()=>{if(document.hidden||!sel)return;if(es&&es.readyState===2)connect();refresh();loadTab();});
