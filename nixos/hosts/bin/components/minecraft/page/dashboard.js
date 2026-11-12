const rows={};
let names=null;
const versionLists={};
const versions=async(type)=>versionLists[type]??=await json("versions?type="+type);
async function fillVersions(s,type,v){
  s.disabled=true;
  try{s.replaceChildren(...(await versions(type)).map((x)=>new Option(x,x)));if(v)s.value=v;}catch(e){msg(e.message,true);}
  s.disabled=false;
}
const memOptions=(s,v)=>{s.replaceChildren(...Array.from({length:16},(_,i)=>new Option((i+1)+" GB",(i+1)+"G")));s.value=v;};
async function load(){
  let list;
  try{list=await json("servers");}catch{return;}
  const on=list.reduce((a,s)=>a+(s.players?s.players.online:0),0);
  $("total").textContent=list.length?list.length+(on?" · "+on+" playing":""):"";
  const key=list.map((s)=>s.name).join();
  if(key!==names){
    names=key;
    $("list").replaceChildren(...list.map((s)=>rows[s.name]=li(el("div","line"))));
    if(!list.length)$("list").append(li(el("span","dim","no servers yet")));
  }
  for(const s of list)draw(rows[s.name],s);
}
function draw(r,s){
  r.s=s;
  const ph=phase(s),up=s.state==="active"||s.state==="activating";
  const a=el("a",null,s.name);a.href="/"+encodeURIComponent(s.name);
  const meta=[s.type+" "+s.version,"port "+s.port,s.players&&s.players.online+"/"+s.players.max,up&&gb(s.used)+" / "+s.memory,up&&s.cpu+"% cpu",s.tick&&ms(s.tick.avg)].filter(Boolean).join(" · ");
  const power=btn(up?"stop":"start",async()=>{
    if(up&&s.players&&s.players.online&&!confirm("stop "+s.name+"? "+s.players.online+" online"))return;
    await post(s.name+"/"+(up?"stop":"start"));msg((up?"stopping ":"starting ")+s.name);setTimeout(load,800);
  },up?"del":"");
  power.disabled=s.state==="deactivating";
  const n=el("span","n");
  if(s.icon)n.append(img("/api/"+encodeURIComponent(s.name)+"/icon/current?v="+s.icon),document.createTextNode(" "));
  n.append(a," ",el("span","st "+ph,ph));
  r.firstChild.replaceChildren(n,el("span","dim",meta),power,btn(r.form?"close":"edit",()=>edit(r)));
}
function field(label,input){const l=el("label");l.append(label,input);return l;}
function check(label,on){const l=el("label","b"),i=el("input");i.type="checkbox";i.checked=!!on;l.append(i," "+label);l.input=i;return l;}
function time(v){const i=el("input");i.type="time";i.value=v||"";return i;}
function edit(r){
  if(r.form){r.form.remove();r.form=null;draw(r,r.s);return;}
  const s=r.s,up=s.state!=="inactive"&&s.state!=="failed";
  const f=el("form","form");
  const mem=el("select");memOptions(mem,s.memory);
  const ver=el("select");ver.append(new Option(s.version,s.version));
  if(up)ver.disabled=true;else fillVersions(ver,s.type,s.version);
  const port=el("input");port.value=String(s.port);port.inputMode="numeric";
  const backup=time(s.backup),restart=time(s.restart);
  const auto=check("start on boot",s.autostart),pub=check("public stats",s.public);
  const bar=el("p","tools wide");
  bar.append(btn("save",async()=>{
    const body={memory:mem.value,port:Number(port.value),backup:backup.value||null,restart:restart.value||null,autostart:auto.input.checked,public:pub.input.checked};
    if(!up&&ver.value!==s.version){if(!confirm("switch to "+ver.value+"? worlds can't go back"))return;body.version=ver.value;msg("downloading "+ver.value);}
    await api(s.name+"/config",{method:"PUT",body:JSON.stringify(body)});
    msg(s.name+" saved"+(up&&(body.memory!==s.memory||body.port!==s.port)?", restart to apply":""));
    edit(r);load();
  }),btn("delete",async()=>{
    if(prompt("type "+s.name+" to delete it. a backup is kept")!==s.name)return;
    await api(s.name,{method:"DELETE"});
    msg("deleting "+s.name);edit(r);setTimeout(load,4000);
  },"del"),el("span","dim",s.type+" "+s.version+(s.loader?" · loader "+s.loader:"")));
  f.append(field("memory",mem),field(up?"version (stop first)":"version",ver),field("port",port),field("backup",backup),field("restart",restart),auto,pub,bar);
  f.onsubmit=(e)=>e.preventDefault();
  r.form=f;r.append(f);draw(r,s);
}
const nf=$("nform");
memOptions(nf.memory,"4G");
fillVersions(nf.version,"fabric");
nf.type.onchange=()=>fillVersions(nf.version,nf.type.value);
nf.onsubmit=async(e)=>{
  e.preventDefault();
  const b=nf.querySelector("button");b.disabled=true;$("nstate").textContent="downloading…";
  try{
    const body={name:nf.name.value.trim(),type:nf.type.value,version:nf.version.value,memory:nf.memory.value,port:nf.port.value.trim()?Number(nf.port.value):null,backup:nf.backup.value||null,restart:nf.restart.value||null,autostart:nf.autostart.checked,public:nf.public.checked,start:nf.start.checked};
    const r=await (await api("servers",{method:"POST",body:JSON.stringify(body)})).json();
    msg(r.name+" created on port "+r.port);
    nf.name.value="";nf.port.value="";$("new").open=false;load();
  }catch(e){msg(e.message,true);}
  b.disabled=false;$("nstate").textContent="";
};
load();setInterval(load,3000);
