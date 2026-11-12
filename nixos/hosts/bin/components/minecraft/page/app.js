const parts=location.pathname.split("/").filter(Boolean).map(decodeURIComponent);
const sel=parts[0],tab=parts[1]||"console",sub=parts[2]||"";
const base="/"+encodeURIComponent(sel);
const A=(p)=>encodeURIComponent(sel)+"/"+p;
const pane=tab==="players"&&sub?"profile":tab;
let cur=null,known=[],hook=null,dirty=false;
document.title=tab==="console"?sel:sel+" "+tab;
$("name").textContent=sel;
for(const a of $("tabs").children){a.href=base+(a.dataset.t==="console"?"":"/"+a.dataset.t);if(a.dataset.t===tab)a.className="on";}
document.querySelector("[data-pane='"+pane+"']").hidden=false;
const online=()=>cur&&cur.players?cur.players.online:0;
const live=()=>!!cur&&cur.state==="active";
const restartOk=(what)=>!live()||confirm(what+" restarts "+sel+(online()?", "+online()+" online":"")+". go on?");
const plink=(n)=>{const a=el("a",null,n);a.href=base+"/players/"+encodeURIComponent(n);return a;};
const pretty=(k)=>k.replace(/_/g," ");
async function refresh(){
  let list;
  try{list=await json("servers");}catch{return;}
  const s=list.find((x)=>x.name===sel);
  if(!s){$("state").textContent="not found";return;}
  cur=s;
  const ph=phase(s),up=s.state==="active"||s.state==="activating",p=s.players;
  $("state").textContent=ph;$("state").className="st "+ph;
  for(const b of document.querySelectorAll("[data-a]"))b.disabled=b.dataset.a==="start"?up||s.state==="deactivating":!up;
  $("meta").textContent=[s.type+" "+s.version,"port "+s.port,p&&p.online+"/"+p.max+" players"+(p.pendingMax?" ("+p.pendingMax+" after restart)":"")].filter(Boolean).join(" · ");
  $("lag").textContent=s.lag?"lagging, "+s.lag.count+"× in 10 min, up to "+(s.lag.max/1000).toFixed(1)+"s behind":"";
  const icon=s.icon?"/api/"+A("icon/current?v="+s.icon):"";
  if($("icon").getAttribute("src")!==icon){$("icon").hidden=!icon;if(icon)$("icon").src=icon;}
  if(hook)hook();
}
for(const b of document.querySelectorAll("[data-a]"))b.onclick=async()=>{
  const a=b.dataset.a;
  if(a!=="start"&&online()&&!confirm(a+" "+sel+"? "+online()+" online"))return;
  b.disabled=true;
  try{await post(A(a));msg(a+" "+sel);}catch(e){msg(e.message,true);}
  refresh();
};
addEventListener("keydown",(e)=>{
  const t=e.target;
  if(t.closest("input,textarea,select")){if(e.key==="Escape")t.blur();return;}
  if(e.ctrlKey||e.metaKey||e.altKey)return;
  if(e.key==="/"){e.preventDefault();if(tab==="console")$("cmd").focus();else location=base+"#cmd";return;}
  const a=$("tabs").children[Number(e.key)-1];
  if(a)location=a.href;
});
addEventListener("beforeunload",(e)=>{if(dirty)e.preventDefault();});

function consolePane(){
  const log=$("log"),cmd=$("cmd");
  let es=null,hist=[],hi=0,matches=[];
  hook=()=>{cmd.disabled=!live();cmd.placeholder=!live()?"server is offline":$("chat").checked?"message everyone":"command";};
  const isChat=(t)=>{
    const i=t.indexOf("]: "),raw=i<0?t:t.slice(i+3);
    if(/^(Player |Disguised )?[Cc]hat: /.test(raw))return true;
    const m=raw.replace(/^System chat: /,"");
    return m.startsWith("<")||m.startsWith("[Server]")||m.startsWith("[Not Secure]")||m.endsWith(" joined the game")||m.endsWith(" left the game");
  };
  const line=(t,cls)=>{
    const s=el("span",cls,t+"\n");
    if(!cls&&(t.includes("/ERROR]")||t.includes("Exception")||t.startsWith("\tat ")))s.className="e";
    else if(!cls&&(t.includes("/WARN]")||t.startsWith("WARNING")))s.className="w";
    if(!isChat(t)&&cls!=="c")s.classList.add("x");
    const f=$("filter").value.toLowerCase();
    if(f&&!t.toLowerCase().includes(f))s.classList.add("h");
    log.append(s);
    while(log.childNodes.length>3000)log.firstChild.remove();
    if($("follow").checked)log.scrollTop=log.scrollHeight;
  };
  const connect=()=>{
    let first=true;
    es=new EventSource("/api/"+A("console"));
    es.onopen=()=>{first=true;};
    es.onmessage=(e)=>{if(first){log.textContent="";first=false;}line(e.data);};
  };
  document.addEventListener("visibilitychange",()=>{if(!document.hidden&&es.readyState===2)connect();});
  $("filter").oninput=()=>{
    const f=$("filter").value.toLowerCase();
    for(const s of log.children)s.classList.toggle("h",!!f&&!s.textContent.toLowerCase().includes(f));
    if($("follow").checked)log.scrollTop=log.scrollHeight;
  };
  $("chat").onchange=()=>{log.classList.toggle("chat",$("chat").checked);log.scrollTop=log.scrollHeight;hook();suggest();};
  $("clear").onclick=()=>{log.textContent="";};
  const P="player",modes=["survival","creative","adventure","spectator"];
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
  const players=()=>[...new Set([...(cur&&cur.players?cur.players.list:[]),...known,"@a","@p","@r","@s"])];
  const suggest=()=>{
    const box=$("sugg");box.textContent="";matches=[];
    const v=cmd.value;
    if($("chat").checked||!v||document.activeElement!==cmd)return;
    const p=v.replace(/^\//,"").split(" "),i=p.length-1,word=p[i].toLowerCase();
    let opts=[];
    if(i===0)opts=Object.keys(grammar);
    else{const g=grammar[p[0].toLowerCase()],slot=g&&g[i-1];opts=slot===P?players():Array.isArray(slot)?slot:[];}
    matches=opts.filter((o)=>o.toLowerCase().startsWith(word)&&o.toLowerCase()!==word).slice(0,10);
    matches.forEach((m,k)=>{const c=el("span",k?"":"on",m);c.onmousedown=(e)=>{e.preventDefault();accept(m);};box.append(c);});
    if(matches.length)box.append(el("em",null,"tab"));
  };
  const accept=(m)=>{
    const p=cmd.value.split(" ");
    p[p.length-1]=(p.length===1&&cmd.value.startsWith("/")?"/":"")+m;
    cmd.value=p.join(" ")+" ";cmd.focus();suggest();
  };
  const send=async(v)=>{
    line("> "+v,"c");
    try{await post(A("command"),v);}catch(e){line("! "+e.message,"e");}
  };
  cmd.oninput=cmd.onfocus=suggest;
  cmd.onblur=()=>setTimeout(()=>{if(document.activeElement!==cmd)$("sugg").textContent="";},100);
  cmd.onkeydown=(e)=>{
    if(e.key==="Tab"){e.preventDefault();if(matches.length)accept(matches[0]);return;}
    if(e.key==="ArrowUp"&&hi>0){cmd.value=hist[--hi];e.preventDefault();suggest();return;}
    if(e.key==="ArrowDown"){hi=Math.min(hist.length,hi+1);cmd.value=hist[hi]??"";e.preventDefault();suggest();return;}
    if(e.key!=="Enter")return;
    let v=cmd.value.trim();if(!v)return;
    if(hist[hist.length-1]!==v)hist.push(v);
    hi=hist.length;cmd.value="";$("sugg").textContent="";matches=[];
    $("follow").checked=true;
    if($("chat").checked)v="say "+v;
    send(v);
  };
  connect();hook();
  if(location.hash==="#cmd"){history.replaceState(null,"",base);cmd.focus();}
}

function playersPane(){
  let last=0;
  const act=async(action,player,extra)=>{await post(A("player"),{action,player,extra});msg(action+(player?" "+player:"")+" sent");setTimeout(load,900);};
  const add=(label,fn)=>{
    const s=el("span"),i=el("input");i.placeholder="player";i.spellcheck=false;i.autocomplete="off";
    const go=async()=>{const v=i.value.trim();if(!/^[A-Za-z0-9_]{1,16}$/.test(v))throw new Error("not a valid player name");await fn(v);i.value="";};
    i.onkeydown=(e)=>{if(e.key==="Enter")go().catch((x)=>msg(x.message,true));};
    s.append(i,btn(label,go));return s;
  };
  const prow=(n,...b)=>{const s=el("span","n");s.append(plink(n));return li(head(n),s,...b);};
  const load=async()=>{
    last=Date.now();
    const box=$("players");
    let d;
    try{d=await json(A("players"));}catch(e){box.textContent=e.message;return;}
    known=d.known;
    const on=live(),p=cur&&cur.players,sec=(title,...x)=>{const h=el("h2",null,title+" ");h.append(...x);const r=el("ul","rows");box.append(h,r);return r;};
    box.textContent="";
    if(!on)box.append(el("p","warn","offline, start the server to change these"));
    const o=sec("online",el("span",null,p?p.online+"/"+p.max:""));
    if(!p||!p.list.length)o.append(li(el("span","dim",p?"nobody online":"server is offline")));
    else for(const n of p.list){
      const op=d.ops.includes(n);
      o.append(prow(n,btn(op?"deop":"op",()=>act(op?"deop":"op",n)),btn("kick",()=>confirm("kick "+n+"?")&&act("kick",n),"del"),btn("ban",()=>{const r=prompt("ban "+n+"? reason, optional");return r!==null&&act("ban",n,r);},"del")));
    }
    const wl=d.whitelist.enabled;
    const t=btn(wl?"on":"off",()=>act("whitelist","",wl?"off":"on"),wl?"on":"");t.title=wl?"only listed players can join":"anyone can join";
    const w=sec("whitelist",t,add("add",(v)=>act("allow",v)));
    if(!d.whitelist.list.length)w.append(li(el("span","dim","nobody whitelisted")));
    for(const n of d.whitelist.list)w.append(prow(n,btn("remove",()=>act("disallow",n),"del")));
    const ops=sec("operators",add("op",(v)=>act("op",v)));
    if(!d.ops.length)ops.append(li(el("span","dim","no operators")));
    for(const n of d.ops)ops.append(prow(n,btn("deop",()=>act("deop",n))));
    const bans=sec("banned",add("ban",(v)=>act("ban",v)));
    if(!d.bans.length)bans.append(li(el("span","dim","nobody banned")));
    for(const b of d.bans){
      const r=prow(b.name,btn("pardon",()=>act("pardon",b.name)));
      if(b.reason&&b.reason!=="Banned by an operator.")r.children[1].append(" ",el("span","dim",b.reason));
      bans.append(r);
    }
    if(!on)for(const x of box.querySelectorAll("button,input"))x.disabled=true;
  };
  hook=()=>{if(!$("players").contains(document.activeElement)&&Date.now()-last>5000)load();};
  load();
}

async function profilePane(){
  const n=sub,box=$("profile");
  document.title=sel+" "+n;
  const t=el("p","dim","loading…");
  const h=el("h1");h.append(img("https://mc-heads.net/avatar/"+encodeURIComponent(n)+"/32","head")," "+n);
  box.append(h,t);
  let p;
  try{p=await json(A("profile/"+encodeURIComponent(n)));}catch(e){t.textContent=e.message;return;}
  t.textContent=p.online?"online now":p.last?"last seen "+ago(p.last):"never joined";
  const s=p.stats,dl=el("dl"),dist=(cm)=>cm>=100000?(cm/100000).toFixed(1)+" km":Math.round(cm/100)+" m",hearts=(v)=>num(Math.round(v/2))+" ♥";
  const kv=(k,v)=>dl.append(el("dt",null,k),el("dd",null,v));
  kv("playtime",s&&s.playtime?dur(s.playtime):p.playtime?dur(p.playtime):"–");
  kv("sessions",String(p.sessions));
  kv("longest session",p.longest?dur(p.longest):"–");
  kv("deaths",String(s?s.deaths:p.deaths));
  kv("advancements",String(p.advancements));
  kv("kicked",String(p.kicks));
  kv("first seen",p.first?when(p.first):"–");
  kv("last seen",p.online?"now":p.last?when(p.last):"–");
  if(s){
    for(const [k,v,f] of [["mob kills",s.mobKills,num],["player kills",s.playerKills,num],["damage dealt",s.damageDealt,hearts],["damage taken",s.damageTaken,hearts],["distance",s.distance,dist],["jumps",s.jumps,num],["blocks mined",s.mined,num],["items crafted",s.crafted,num],["tools broken",s.broken,num],["fish caught",s.fish,num],["animals bred",s.bred,num],["villager trades",s.trades,num],["items enchanted",s.enchants,num],["nights slept",s.sleeps,num]])kv(k,f(v));
    kv("alive for",s.sinceDeath?dur(s.sinceDeath):"–");
  }
  box.append(dl);
  const list=(title,items)=>{if(!items.length)return;const r=el("ul","rows");for(const [a,b] of items)r.append(li(el("span","n",a),el("span","dim",b)));box.append(el("h2",null,title),r);};
  list("recent deaths",p.recentDeaths.map((d)=>[n+" "+d.text,ago(d.t)]));
  list("recent advancements",p.recentAdvancements.map((d)=>[d.text,ago(d.t)]));
  if(s)for(const [title,l,f] of [["travel",s.travel,dist],["most mined",s.topMined,num],["most killed",s.topKilled,num],["killed by",s.killedBy,num],["most crafted",s.topCrafted,num]])list(title,l.map(([k,v])=>[pretty(k),f(v)]));
}

async function activityPane(){
  const box=$("activity");
  let list;
  try{list=await json(A("activity"));}catch(e){box.textContent=e.message;return;}
  if(!list.length){box.append(li(el("span","dim","nothing in the last 7 days")));return;}
  for(const a of list){
    const n=el("span","n");
    n.append(plink(a.player)," "+(a.type==="advancement"?"made the advancement ["+a.text+"]":a.text));
    const d=el("span","dim",ago(a.t));d.title=new Date(a.t).toLocaleString();
    box.append(li(head(a.player),n,el("span","tag "+a.type,a.type),d));
  }
}

function modsPane(){
  const kind={"":"mod",datapacks:"datapack",resourcepack:"pack"}[sub]||"mod";
  const paths={mod:"/mods",datapack:"/mods/datapacks",pack:"/mods/resourcepack"};
  for(const a of $("kinds").children){a.href=base+paths[a.dataset.k];if(a.dataset.k===kind)a.className="on";}
  hook=()=>{
    $("kinds").firstChild.hidden=cur.type==="vanilla";
    if(cur.type==="vanilla"&&kind==="mod")location.replace(base+paths.datapack);
  };
  hook();
  if(kind==="pack")return packView();
  $("modview").hidden=false;
  const kq="kind="+kind,noun=(n)=>kind+(n===1?"":"s");
  let installed=[],timer=null;
  $("msearch").placeholder="search modrinth "+noun(2);
  $("mreload").hidden=kind!=="datapack";
  $("mreload").onclick=async()=>{try{await post(A("command"),"reload");msg("reloading datapacks");}catch(e){msg(e.message,true);}};
  const changed=(t)=>msg(t+(kind==="mod"?", restart to apply":", reload or restart to apply"));
  const update=(m)=>post(A("mods/install?"+kq),{project:m.project});
  const load=async()=>{
    let list;
    $("mcount").textContent="loading…";
    try{list=await json(A("mods?"+kq));}catch(e){$("mcount").textContent=e.message;return;}
    installed=list;
    const out=list.filter((m)=>m.update),box=$("minstalled");
    $("mcount").textContent=list.length+(out.length?" · "+out.length+" to update":"");
    $("mall").replaceChildren(...(out.length>1?[btn("update all",async(b)=>{
      for(const [i,m] of out.entries()){b.textContent="updating "+(i+1)+"/"+out.length+"…";await update(m);}
      changed("updated "+out.length+" "+noun(2));load();
    })]:[]));
    box.textContent="";
    if(!list.length)box.append(li(el("span","dim","no "+noun(2)+" yet, search above")));
    for(const m of list){
      const n=el("span","n",m.title||m.file);
      n.append(el("small",null,(m.version?m.version+" · ":"")+m.file+" · "+mbs(m.size)));
      const r=li(img(m.icon),n);
      if(m.update){const u=btn("update",async()=>{await update(m);changed("updated "+(m.title||m.file)+" to "+m.update);load();},"on");u.title=m.update;r.append(u);}
      r.append(btn("remove",async()=>{
        if(!confirm("remove "+(m.title||m.file)+"?"))return;
        await api(A("mods/"+encodeURIComponent(m.file)+"?"+kq),{method:"DELETE"});
        changed("removed "+(m.title||m.file));load();
      },"del"));
      box.append(r);
    }
    if($("msearch").value.trim())search();
  };
  const search=async()=>{
    const q=$("msearch").value.trim(),box=$("mresults");
    if(!q){box.textContent="";$("mnote").textContent="";return;}
    $("mnote").textContent="searching…";
    let hits;
    try{hits=await json(A("mods/search?"+kq+"&q="+encodeURIComponent(q)));}catch(e){$("mnote").textContent=e.message;return;}
    if($("msearch").value.trim()!==q)return;
    $("mnote").textContent=hits.length?hits.length+" for "+cur.version:"nothing for "+cur.version;
    box.textContent="";
    for(const h of hits){
      const n=el("span","n"),a=el("a",null,h.title);
      a.href="https://modrinth.com/"+kind+"/"+h.slug;a.target="_blank";a.rel="noopener";
      n.append(a,el("small",null,h.description));
      const r=li(img(h.icon),n,el("span","dim",num(h.downloads)));
      if(installed.some((m)=>m.project===h.project))r.append(el("span","dim","installed"));
      else r.append(btn("install",async(b)=>{
        b.textContent="installing…";
        const res=await (await post(A("mods/install?"+kq),{project:h.project})).json();
        changed("installed "+res.map((x)=>x.file).join(", "));load();
      }));
      box.append(r);
    }
  };
  $("msearch").oninput=()=>{clearTimeout(timer);timer=setTimeout(search,400);};
  load();
}

function packView(){
  $("packview").hidden=false;
  let timer=null;
  const applied=(t)=>msg(t+(live()?", server restarting":""));
  const load=async()=>{
    let p;
    try{p=await json(A("pack"));}catch(e){$("pstat").textContent=e.message;return;}
    const box=$("pcurrent");box.textContent="";
    $("preq").checked=p.required;$("pprompt").value=p.prompt;
    $("pstat").textContent=p.url?p.required?"required":"optional":"";
    if(!p.url){box.append(li(el("span","dim","no server pack")));return;}
    const m=p.meta,n=el("span","n",m?m.title:"external pack");
    n.append(el("small",null,(m&&m.version?m.version+" · ":"")+(m?mbs(m.size)+" · ":"")+p.url));
    box.append(li(img(m&&m.icon),n,btn("remove",async()=>{
      if(!restartOk("removing the pack"))return;
      await api(A("pack"),{method:"DELETE"});applied("pack removed");load();
    },"del")));
  };
  $("psave").onclick=async()=>{
    if(!restartOk("saving"))return;
    try{const r=await (await post(A("pack/settings"),{required:$("preq").checked,prompt:$("pprompt").value})).json();msg("pack settings saved"+(r.restarted?", server restarting":""));load();}
    catch(e){msg(e.message,true);}
  };
  $("pupload").onclick=()=>$("pfile").click();
  $("pfile").onchange=async()=>{
    const f=$("pfile").files[0];$("pfile").value="";
    if(!f)return;
    if(!/\.zip$/i.test(f.name))return msg("pick a .zip file",true);
    if(f.size>250*1048576)return msg("pack is larger than 250 MB",true);
    if(!restartOk("using a new pack"))return;
    msg("uploading "+mbs(f.size)+"…");
    try{const r=await (await api(A("pack/upload?name="+encodeURIComponent(f.name)),{method:"POST",body:f})).json();msg("pack active"+(r.restarted?", server restarting":""));load();}
    catch(e){msg("upload failed: "+e.message,true);}
  };
  const search=async()=>{
    const q=$("psearch").value.trim(),box=$("presults");
    if(!q){box.textContent="";$("psnote").textContent="";return;}
    $("psnote").textContent="searching…";
    let hits;
    try{hits=await json(A("pack/search?q="+encodeURIComponent(q)));}catch(e){$("psnote").textContent=e.message;return;}
    if($("psearch").value.trim()!==q)return;
    $("psnote").textContent=hits.length?hits.length+" for "+cur.version:"nothing for "+cur.version;
    box.textContent="";
    for(const h of hits){
      const n=el("span","n"),a=el("a",null,h.title);
      a.href="https://modrinth.com/resourcepack/"+h.slug;a.target="_blank";a.rel="noopener";
      n.append(a,el("small",null,h.description));
      box.append(li(img(h.icon),n,el("span","dim",num(h.downloads)),btn("use",async(b)=>{
        if(!restartOk("using a new pack"))return;
        b.textContent="downloading…";
        const r=await (await post(A("pack/install"),{project:h.project})).json();
        msg(h.title+" is the server pack"+(r.restarted?", server restarting":""));load();
      })));
    }
  };
  $("psearch").oninput=()=>{clearTimeout(timer);timer=setTimeout(search,400);};
  load();
}

function worldPane(){
  let data=null,busy=null,timer=null;
  const labels={reset:"creating a new world",nether:"resetting the nether",end:"resetting the end",import:"importing the uploaded world"};
  const done={reset:"new world created",nether:"nether reset",end:"end reset",import:"world imported"};
  const flat=[["classic","minecraft:bedrock,2*minecraft:dirt,minecraft:grass_block;minecraft:plains"],["tunnelers dream","minecraft:bedrock,230*minecraft:stone,5*minecraft:dirt,minecraft:grass_block;minecraft:windswept_hills"],["water world","minecraft:bedrock,5*minecraft:stone,5*minecraft:dirt,5*minecraft:sand,90*minecraft:water;minecraft:deep_ocean"],["snowy kingdom","minecraft:bedrock,59*minecraft:stone,3*minecraft:dirt,minecraft:grass_block,minecraft:snow;minecraft:snowy_plains"],["desert","minecraft:bedrock,3*minecraft:stone,52*minecraft:sandstone,8*minecraft:sand;minecraft:desert"],["redstone ready","minecraft:bedrock,3*minecraft:stone,116*minecraft:sandstone;minecraft:desert"],["the void","minecraft:air;minecraft:the_void"]];
  const defaults={"spawn_wandering_traders":true,"block_drops":true,"reduced_debug_info":false,"show_death_messages":true,"spawn_monsters":true,"spawner_blocks_work":true,"tnt_explodes":true,"player_movement_check":true,"immediate_respawn":false,"spread_vines":true,"block_explosion_drop_decay":true,"max_entity_cramming":24,"forgive_dead_players":true,"fall_damage":true,"send_command_feedback":true,"global_sound_events":true,"elytra_movement_check":true,"fire_spread_radius_around_player":128,"freeze_damage":true,"mob_explosion_drop_decay":true,"natural_health_regeneration":true,"players_nether_portal_default_delay":80,"mob_drops":true,"log_admin_commands":true,"mob_griefing":true,"pvp":true,"spawn_mobs":true,"spectators_generate_chunks":true,"players_sleeping_percentage":100,"players_nether_portal_creative_delay":0,"max_command_sequence_length":65536,"advance_weather":true,"max_block_modifications":32768,"max_command_forks":65536,"drowning_damage":true,"locator_bar":true,"command_block_output":true,"show_advancement_messages":true,"respawn_radius":10,"raids":true,"spawn_phantoms":true,"max_snow_accumulation_height":1,"limited_crafting":false,"allow_entering_nether_using_portals":true,"lava_source_conversion":false,"tnt_explosion_drop_decay":false,"keep_inventory":false,"universal_anger":false,"spawn_patrols":true,"random_tick_speed":3,"fire_damage":true,"entity_drops":true,"advance_time":true,"command_blocks_work":true,"spawn_wardens":true,"projectiles_can_break_blocks":true,"water_source_conversion":true,"ender_pearls_vanish_on_death":true};
  const changes=()=>data&&data.rules?Object.entries(defaults).filter(([k,v])=>k in data.rules&&String(data.rules[k])!==String(v)):[];
  const copy=(t)=>{
    const a=el("textarea");a.value=t;a.readOnly=true;a.style.cssText="position:fixed;top:0;opacity:0;font-size:16px";
    document.body.append(a);a.select();a.setSelectionRange(0,t.length);
    let ok=false;try{ok=document.execCommand("copy");}catch{}
    a.remove();msg(ok?"copied":"could not copy",!ok);
  };
  const rules=()=>{
    const box=$("wrules");box.textContent="";
    if(!data)return;
    if(!data.rules){box.append(li(el("span","dim","no game rules in the world file yet")));return;}
    const on=live(),f=$("wfilter").value.trim().toLowerCase(),ch=changes();
    $("wdefaults").disabled=!on||!ch.length;
    $("wdefaults").title=ch.length?ch.length+" changed":"all default";
    if(!on)box.append(li(el("span","warn","start the server to change rules")));
    const set=async(k,v)=>{await post(A("command"),"gamerule "+k+" "+v);const o=data.rules[k];data.rules[k]=typeof o==="boolean"?v==="true":typeof o==="number"?Number(v):v;msg(k+" = "+v);rules();};
    for(const k of Object.keys(data.rules).sort().filter((k)=>!f||k.includes(f))){
      const v=data.rules[k],r=li(el("span","n",pretty(k)));
      if(v===true||v===false||v==="true"||v==="false"){
        const yes=v===true||v==="true",b=btn(yes?"on":"off",()=>set(k,yes?"false":"true"),yes?"on":"");
        b.disabled=!on;r.append(b);
      }else{
        const i=el("input","num");i.value=String(v);i.disabled=!on;
        i.onkeydown=(e)=>{if(e.key==="Enter")i.blur();};
        i.onchange=()=>{const x=i.value.trim();if(!/^-?\d+$/.test(x)){msg("enter a whole number",true);i.value=String(v);return;}set(k,x).catch((e)=>msg(e.message,true));};
        r.append(i);
      }
      box.append(r);
    }
  };
  $("wfilter").oninput=rules;
  $("wdefaults").onclick=async()=>{
    const ch=changes();
    if(!ch.length||!confirm("reset "+ch.length+" rule"+(ch.length>1?"s":"")+" to default?"))return;
    for(const [k,v] of ch){await post(A("command"),"gamerule "+k+" "+v);data.rules[k]=v;}
    msg("rules reset");rules();
  };
  const ask=(what)=>confirm(what+"? a backup is made first"+(live()?", the server restarts"+(online()?" and "+online()+" online get disconnected":""):""));
  const act=async(action,extra)=>{await post(A("world/action"),{action,...extra});busy=action;load();};
  const load=async()=>{
    clearTimeout(timer);
    let w;
    try{w=await json(A("world"));}catch(e){$("winfo").textContent=e.message;return;}
    data=w;
    if(busy&&!w.busy&&w.last)msg(w.last.ok?done[w.last.action]:"failed: "+(w.last.message||w.last.action),!w.last.ok);
    busy=w.busy;
    if(w.busy)timer=setTimeout(load,2000);
    $("wnote").textContent=w.busy?labels[w.busy]+"… the server is stopped":w.last&&!w.last.ok?"last task failed: "+(w.last.message||w.last.action)+", "+ago(w.last.t):"";
    const dl=$("winfo");dl.textContent="";
    const kv=(k,v,c)=>{const d=el("dd",null,v);if(c){d.className="c";d.title="copy";d.onclick=()=>copy(v);}dl.append(el("dt",null,k),d);};
    if(!w.exists)kv("world","created on first start");
    else{
      kv("world",w.name||w.level);
      if(w.version)kv("version",w.version);
      if(w.seed)kv("seed",w.seed,true);
      kv("difficulty",(w.difficulty||"–")+(w.hardcore?", hardcore":""));
      if(w.day)kv("day",String(w.day));
      if(w.spawn)kv("spawn",w.spawn.join(" "),true);
      if(w.lastPlayed)kv("last saved",ago(w.lastPlayed));
    }
    const total=Object.values(w.sizes).reduce((a,b)=>a+b,0);
    $("wtotal").textContent=total?mbs(total):"";
    const sz=$("wsize");sz.textContent="";
    const kinds=["overworld","nether","end","players","datapacks","other"].filter((k)=>w.sizes[k]);
    if(!kinds.length)sz.append(li(el("span","dim","nothing on disk yet")));
    for(const k of kinds)sz.append(li(el("span","n",k),el("span","dim",mbs(w.sizes[k]))));
    rules();
    const m=$("wmanage");m.textContent="";
    const row=(t,...x)=>{const r=li(el("span","n",t),...x);m.append(r);return r;};
    row("download the world",btn("download",async(b)=>{
      const before=new Set((await json(A("backups"))).map((x)=>x.file));
      await post(A("backup"));
      b.textContent="backing up…";
      try{
        for(let i=0;i<300;i++){
          await new Promise((r)=>setTimeout(r,2000));
          const n=(await json(A("backups"))).find((x)=>!before.has(x.file));
          if(n){location.href="/api/"+A("backups/"+n.file);return;}
        }
        throw new Error("the backup took too long");
      }finally{b.textContent="download";}
    }));
    row("upload a world",btn("upload",async()=>$("wfile").click()));
    row("reset the nether",btn("reset",async()=>{if(ask("reset the nether"))await act("nether");},"del"));
    row("reset the end",btn("reset",async()=>{if(ask("reset the end"))await act("end");},"del"));
    const seed=el("input");seed.placeholder="seed, empty for random";seed.value=w.seedProp;seed.maxLength=64;
    const type=el("select");
    for(const [v,l] of [["minecraft:normal","normal"],["minecraft:flat","flat"],["minecraft:large_biomes","large biomes"],["minecraft:amplified","amplified"]])type.append(new Option(l,v));
    type.value=w.typeProp;
    const pick=el("select"),preset=el("input","wide");
    preset.placeholder="layers;biome";preset.maxLength=2000;preset.value=w.presetProp||flat[0][1];
    for(const [l,v] of flat)pick.append(new Option(l,v));
    pick.append(new Option("custom",""));
    const sync=()=>{pick.value=flat.some(([,v])=>v===preset.value)?preset.value:"";};
    pick.onchange=()=>{if(pick.value)preset.value=pick.value;else preset.focus();};
    preset.oninput=sync;sync();
    row("new world",seed,type,btn("create",async()=>{if(ask("replace this world"))await act("reset",{seed:seed.value,type:type.value,preset:preset.value});},"del"));
    const fr=row("flat layers",pick,preset);
    const show=()=>{fr.hidden=type.value!=="minecraft:flat";};
    type.onchange=show;show();
    if(w.busy)for(const x of m.querySelectorAll("button,input,select"))x.disabled=true;
  };
  $("wfile").onchange=async()=>{
    const f=$("wfile").files[0];$("wfile").value="";
    if(!f)return;
    if(!/\.(zip|tar\.gz|tgz)$/i.test(f.name))return msg("pick a .zip or .tar.gz file",true);
    if(!confirm("replace the world with "+f.name+"? a backup is made first"+(live()?", the server restarts":"")))return;
    const note=$("wnote");
    try{
      await new Promise((res,rej)=>{
        const x=new XMLHttpRequest();
        x.open("POST","/api/"+A("world/upload"));
        x.upload.onprogress=(e)=>{if(e.lengthComputable)note.textContent="uploading "+f.name+", "+Math.round(e.loaded/e.total*100)+"% of "+mbs(f.size);};
        x.onload=()=>x.status<300?res():rej(new Error(x.responseText||x.statusText));
        x.onerror=()=>rej(new Error("connection lost"));
        x.send(f);
      });
      busy="import";load();
    }catch(e){note.textContent="";msg("upload failed: "+e.message,true);}
  };
  let was=null;
  hook=()=>{if(was!==null&&was!==live())load();was=live();};
  load();
}

async function statsPane(){
  const range=86400000;
  hook=()=>{
    const s=cur,up=s.state==="active"||s.state==="activating",dl=$("now");
    dl.textContent="";
    for(const [k,v] of [["memory",up?gb(s.used)+" / "+s.memory:"–"],["cpu",up?s.cpu+"%":"–"],["tick",s.tick?ms(s.tick.avg)+" avg"+(s.tick.p95!=null?", "+ms(s.tick.p95)+" p95":""):"–"],["uptime",s.since?dur(Date.now()-s.since):"–"]])dl.append(el("dt",null,k),el("dd",null,v));
  };
  hook();
  const chart=(title,pts,fmt,max)=>{
    const w=el("div","chart");
    const last=pts.length?pts[pts.length-1][1]:0,peak=pts.reduce((m,p)=>Math.max(m,p[1]),0);
    const l=el("p",null,title+" "),ns="http://www.w3.org/2000/svg",svg=document.createElementNS(ns,"svg");
    l.append(el("span","dim",fmt(last)+", peak "+fmt(peak)));
    svg.setAttribute("viewBox","0 0 1000 100");svg.setAttribute("preserveAspectRatio","none");
    const start=Date.now()-range,top=Math.max(max||0,peak)*1.1||1;
    const xy=pts.map(([t,v])=>((t-start)/range*1000).toFixed(1)+","+(100-v/top*96).toFixed(1));
    if(xy.length>1){const p=document.createElementNS(ns,"path");p.setAttribute("d","M"+xy.join("L"));svg.append(p);}
    w.append(l,svg);
    if(xy.length<2)w.append(el("p","dim","collecting data, one point per minute"));
    return w;
  };
  try{
    const h=(await json(A("history"))).filter((p)=>p[0]>=Date.now()-range);
    $("charts").append(
      chart("players",h.map((p)=>[p[0],p[1]]),String,cur&&cur.players?cur.players.max/4:4),
      chart("memory",h.map((p)=>[p[0],p[2]]),gb,cur?cur.limit:0),
      chart("cpu",h.map((p)=>[p[0],p[3]]),(v)=>v+"%",100),
      chart("tick time",h.filter((p)=>p[4]!=null).map((p)=>[p[0],p[4]]),ms,50),
      chart("slowest ticks",h.filter((p)=>p[5]!=null).map((p)=>[p[0],p[5]]),ms,50));
  }catch(e){$("charts").textContent=e.message;}
}

function tasksPane(){
  let last=null;
  const backups=async()=>{
    const box=$("backups");
    try{
      const list=await json(A("backups"));
      box.textContent="";
      if(!list.length)box.append(li(el("span","dim","no backups yet")));
      for(const b of list){
        const a=el("a","dim","download");a.href="/api/"+A("backups/"+b.file);
        const n=el("span","n",when(b.time));n.append(" ",el("span","dim",mbs(b.size)+", "+ago(b.time)));
        box.append(li(n,a,btn("restore",async()=>{
          if(!confirm("restore the world from "+new Date(b.time).toLocaleString()+"? the current world is kept as a copy"+(online()?", "+online()+" online get disconnected":"")))return;
          await post(A("restore"),{file:b.file});msg("restoring…");
        },"del")));
      }
    }catch(e){box.textContent=e.message;}
  };
  const tasks=async()=>{
    const box=$("tasks");
    if(box.querySelector("button:disabled"))return;
    let t;
    try{t=await json(A("tasks"));}catch(e){box.textContent=e.message;return;}
    const going=t.restart.state==="active"||t.restart.state==="activating";
    const n1=el("span","n","restart with countdown ");
    n1.append(el("span","dim",going?"counting down, players were warned":t.restart.at?"daily at "+t.restart.at+(t.restart.next?", next in "+dur(t.restart.next-Date.now()):""):"5 min warning"));
    const rb=going
      ?btn("cancel",async()=>{await post(A("restart/cancel"));msg("restart cancelled");tasks();},"del")
      :btn("run now",async()=>{if(!confirm("restart "+sel+" in 5 minutes?"))return;await post(A("restart/countdown"));msg("countdown started");tasks();});
    if(!going&&!live())rb.disabled=true;
    const busy=t.backup.state==="activating"||t.backup.state==="active";
    const n2=el("span","n","backup ");
    n2.append(el("span","dim",busy?"running…":(t.backup.at?"daily at "+t.backup.at+(t.backup.next?", next in "+dur(t.backup.next-Date.now()):""):"not scheduled")+(t.backup.result&&t.backup.result!=="success"?", last run failed":"")));
    const bb=btn(busy?"backing up…":"back up now",async()=>{await post(A("backup"));msg("backup started");last="activating";tasks();});
    box.replaceChildren(li(n1,rb),li(n2,bb));
    bb.disabled=busy;
    if(last&&!busy&&last!==t.backup.state){msg(t.backup.result==="success"?"backup finished":"backup failed: "+t.backup.result,t.backup.result!=="success");backups();}
    last=t.backup.state;
  };
  const crashes=async()=>{
    const box=$("crashes");
    let list;
    try{list=await json(A("crashes"));}catch(e){box.textContent=e.message;return;}
    if(!list.length){box.append(li(el("span","dim","no crashes")));return;}
    for(const c of list){
      const d=el("details"),s=el("summary",null,c.startup?"failed to start":c.description||"crash");
      s.append(" ",el("span","dim",ago(c.time)+(c.suspects.length?", suspects: "+c.suspects.join(", "):"")));
      d.append(s);
      if(c.error)d.append(el("p","err",c.error));
      if(c.file)d.append(el("p","dim",c.file));
      d.append(el("pre",null,c.text));
      box.append(li(d));
    }
  };
  hook=tasks;
  tasks();backups();crashes();
}

function settingsPane(){
  const fields=[["motd","message of the day","text",true],["difficulty","difficulty",["peaceful","easy","normal","hard"]],["gamemode","game mode",["survival","creative","adventure","spectator"]],["max-players","max players","number"],["view-distance","view distance","number"],["simulation-distance","simulation distance","number"],["spawn-protection","spawn protection","number"],["pvp","pvp","bool"],["allow-flight","allow flight","bool"],["hardcore","hardcore","bool"]];
  const props=$("props"),state=(t)=>{$("pstate").textContent=t;};
  const get=(txt,k)=>{const l=txt.split("\n").find((x)=>x.startsWith(k+"="));return l==null?null:l.slice(k.length+1);};
  const set=(txt,k,v)=>{const l=txt.split("\n"),i=l.findIndex((x)=>x.startsWith(k+"="));if(i>=0)l[i]=k+"="+v;else{if(l[l.length-1]==="")l.pop();l.push(k+"="+v,"");}return l.join("\n");};
  const changed=()=>{dirty=true;state("unsaved");};
  const form=()=>{
    const f=$("pform");f.textContent="";
    for(const [k,label,type,wide] of fields){
      const v=get(props.value,k),l=el("label",type==="bool"?"b":wide?"wide":"");
      let i;
      if(type==="bool"){i=el("input");i.type="checkbox";i.checked=v==="true";l.append(i," "+label);}
      else{
        if(Array.isArray(type)){i=el("select");for(const o of type)i.append(new Option(o,o));i.value=v??type[0];}
        else{i=el("input");i.type=type;i.value=v??"";if(type==="number")i.min="0";}
        l.append(label,i);
      }
      i.onchange=i.oninput=()=>{props.value=set(props.value,k,type==="bool"?String(i.checked):i.value);changed();};
      f.append(l);
    }
  };
  const load=async()=>{
    state("loading…");
    try{props.value=await (await api(A("properties"))).text();dirty=false;state("");form();}
    catch(e){state(e.message);$("pform").textContent="";}
  };
  props.oninput=changed;
  props.onchange=form;
  $("reload").onclick=()=>{if(!dirty||confirm("discard unsaved changes?"))load();};
  hook=()=>{$("save").textContent=live()?"save and restart":"save";};
  hook();
  $("save").onclick=async()=>{
    const up=live();
    if(up&&online()&&!confirm("save and restart "+sel+"? "+online()+" online"))return;
    $("save").disabled=true;
    try{await api(A("properties"+(up?"?apply":"")),{method:"PUT",body:props.value});dirty=false;state(up?"saved, restarting":"saved, applies on next start");}
    catch(e){msg("save failed: "+e.message,true);}
    $("save").disabled=false;
  };
  const icons=async()=>{
    let d;
    try{d=await json(A("icons"));}catch(e){$("icur").textContent=e.message;return;}
    const t=el("div"),acts=el("p","acts");
    t.append(el("p",null,!d.active?d.live?"no icon after restart":"no icon":d.live===undefined?"active once started":d.live===d.active?"active":"active after restart"),acts);
    if(d.live!==undefined&&(d.live||null)!==d.active)acts.append(btn("restart now",async()=>{if(!restartOk("showing the new icon"))return;await post(A("restart"));msg("restarting "+sel);}));
    if(d.active)acts.append(btn("remove",async()=>{await api(A("icon"),{method:"DELETE"});icons();refresh();},"del"));
    $("icur").replaceChildren(d.active?img("/api/"+A("icon/"+d.active)):el("span","none"),t);
    const use=async(id)=>{try{await post(A("icon/use"),{id});icons();refresh();}catch(e){msg(e.message,true);}};
    $("ilist").replaceChildren(...d.list.map((i)=>{
      const on=i.id===d.active,s=el("div","tile"+(on?" on":"")),im=img("/api/"+A("icon/"+i.id)),p=el("p");
      if(on)p.textContent="in use";
      else{
        im.title="use";im.onclick=()=>use(i.id);
        p.append(btn("use",()=>use(i.id)),btn("delete",async()=>{if(!confirm("delete this icon?"))return;await api(A("icon/"+i.id),{method:"DELETE"});icons();},"del"));
      }
      s.append(im,p);
      return s;
    }));
  };
  const toIcon=async(file)=>{
    const u=URL.createObjectURL(file),b=new Image();b.src=u;
    try{await b.decode();}catch{throw new Error("unsupported image");}finally{URL.revokeObjectURL(u);}
    const side=Math.min(b.naturalWidth,b.naturalHeight),c=el("canvas");c.width=c.height=64;
    const x=c.getContext("2d");x.imageSmoothingEnabled=side>64;x.imageSmoothingQuality="high";
    x.drawImage(b,(b.naturalWidth-side)/2,(b.naturalHeight-side)/2,side,side,0,0,64,64);
    return new Promise((r,j)=>c.toBlob((o)=>o?r(o):j(new Error("could not convert the image")),"image/png"));
  };
  $("iupload").onclick=()=>$("ifile").click();
  $("ifile").onchange=async()=>{
    const f=$("ifile").files[0];$("ifile").value="";
    if(!f)return;
    try{await api(A("icon/upload"),{method:"POST",body:await toIcon(f)});msg("icon uploaded");icons();refresh();}
    catch(e){msg("upload failed: "+e.message,true);}
  };
  icons();load();
}

const panes={console:consolePane,players:playersPane,profile:profilePane,activity:activityPane,mods:modsPane,world:worldPane,stats:statsPane,tasks:tasksPane,settings:settingsPane};
refresh().then(()=>{panes[pane]();setInterval(refresh,2000);});
document.addEventListener("visibilitychange",()=>{if(!document.hidden)refresh();});
