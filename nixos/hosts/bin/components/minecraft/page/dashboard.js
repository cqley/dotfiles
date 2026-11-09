function openModal(...nodes){const b=$("mbody");b.innerHTML="";b.append(...nodes);$("modal").hidden=false;}
function closeModal(){$("modal").hidden=true;}
$("modal").onclick=(e)=>{if(e.target===$("modal"))closeModal();};
$("mclose").onclick=closeModal;
addEventListener("keydown",(e)=>{if(e.key==="Escape")closeModal();});
const icons={};
async function load(){
  let list;
  try{list=await (await api("servers")).json();}catch(e){return;}
  const box=$("list");box.innerHTML="";
  const on=list.reduce((a,s)=>a+(s.players?s.players.online:0),0);
  $("total").textContent=list.length?list.length+" server"+(list.length>1?"s":"")+(on?" · "+on+" playing":""):"";
  if(!list.length)box.append(el("div","empty","no servers yet"));
  for(const s of list){
    const ph=phase(s);
    const d=el("a","srv "+ph);d.href="/"+encodeURIComponent(s.name);
    const top=el("div","top");
    const ik=s.name+s.icon;
    if(s.icon&&!icons[ik])icons[ik]=img("/api/"+encodeURIComponent(s.name)+"/icon/current?v="+s.icon,"si");
    if(s.icon)top.append(icons[ik]);
    top.append(el("span","dot"),el("span",null,s.name),el("span","state",ph));
    const bar=el("div","bar"),i=el("i");bar.append(i);
    i.style.width=Math.min(100,s.used/s.limit*100)+"%";
    d.append(top,el("div","meta",s.type+" "+s.version+" · port "+s.port+(s.players?" · "+s.players.online+"/"+s.players.max+" players":"")),bar,el("div","meta",(s.used?gb(s.used):"0 GB")+" / "+s.memory+" · "+s.cpu+"% cpu"+(s.since?" · up "+ago(s.since):"")));
    const acts=el("div","acts");
    acts.onclick=(e)=>{e.preventDefault();e.stopPropagation();};
    const up=s.state==="active"||s.state==="activating";
    const power=btn(up?"stop":"start",async()=>{
      if(up&&s.players&&s.players.online&&!confirm("stop "+s.name+"? "+s.players.online+" online"))return;
      await post(s.name+"/"+(up?"stop":"start"));toast((up?"stopping ":"starting ")+s.name);setTimeout(load,800);
    },up?"danger":"");
    if(s.state==="deactivating")power.disabled=true;
    acts.append(power,el("span","sp"),btn("edit",()=>editServer(s)));
    d.append(acts);
    box.append(d);
  }
}
const versionLists={};
async function versions(type){return versionLists[type]??=await (await api("versions?type="+type)).json();}
function field(label,input){const l=el("label");l.append(document.createTextNode(label),input);return l;}
function check(label,on){const l=el("label","b"),i=el("input");i.type="checkbox";i.checked=!!on;l.append(i,document.createTextNode(label));l.input=i;return l;}
function pick(values,v){const s=el("select","f");for(const [val,txt] of values){const o=el("option",null,txt);o.value=val;s.append(o);}if(v!=null)s.value=v;return s;}
const memSelect=(v)=>pick(Array.from({length:16},(_,i)=>[(i+1)+"G",(i+1)+" GB"]),v);
function timeInput(v){const i=el("input","f");i.type="time";i.value=v||"";return i;}
async function fillVersions(sel_,type,v){sel_.disabled=true;try{const l=await versions(type);sel_.innerHTML="";for(const x of l){const o=el("option",null,x);o.value=x;sel_.append(o);}if(v)sel_.value=v;}catch(e){toast(e.message,"err");}sel_.disabled=false;}
let newBuilt=false;
function buildNew(){
  if(newBuilt)return;
  newBuilt=true;
  const name=el("input","f");name.placeholder="a–z, 0–9";name.maxLength=16;name.autocapitalize="off";name.spellcheck=false;
  const type=pick([["fabric","fabric"],["vanilla","vanilla"]],"fabric");
  const ver=el("select","f");
  type.onchange=()=>fillVersions(ver,type.value);
  const mem=memSelect("4G");
  const port=el("input","f");port.placeholder="auto";port.inputMode="numeric";
  const backup=timeInput("05:00"),restart=timeInput("04:00");
  const auto=check("start on boot",true),pub=check("public stats",true),now=check("start now",true);
  $("nform").append(field("name",name),field("type",type),field("version",ver),field("memory",mem),field("port",port),field("backup",backup),field("restart",restart),auto,pub,now);
  fillVersions(ver,"fabric");
  $("ngo").append(btn("create",async()=>{
    $("nstate").textContent="downloading…";
    try{
      const body={name:name.value.trim(),type:type.value,version:ver.value,memory:mem.value,port:port.value.trim()?Number(port.value):null,backup:backup.value||null,restart:restart.value||null,autostart:auto.input.checked,public:pub.input.checked,start:now.input.checked};
      const r=await (await api("servers",{method:"POST",body:JSON.stringify(body)})).json();
      toast(r.name+" created · port "+r.port,"ok");
      name.value="";port.value="";
      load();
    }finally{$("nstate").textContent="";}
  }));
}
function editServer(s){
  const up=s.state!=="inactive"&&s.state!=="failed";
  const f=el("div","form");
  const mem=memSelect(s.memory);
  const ver=pick([[s.version,s.version]],s.version);
  if(!up)fillVersions(ver,s.type,s.version);else ver.disabled=true;
  const port=el("input","f");port.value=String(s.port);port.inputMode="numeric";
  const backup=timeInput(s.backup),restart=timeInput(s.restart);
  const auto=check("start on boot",s.autostart),pub=check("public stats",s.public);
  f.append(field("memory",mem),field(up?"version · stop first":"version",ver),field("port",port),field("backup",backup),field("restart",restart),auto,pub);
  const save=btn("save",async()=>{
    const body={memory:mem.value,port:Number(port.value),backup:backup.value||null,restart:restart.value||null,autostart:auto.input.checked,public:pub.input.checked};
    if(!up&&ver.value!==s.version){if(!confirm("switch to "+ver.value+"? worlds can't go back"))return;body.version=ver.value;$("mbody").append(el("div","note","downloading…"));}
    await api(s.name+"/config",{method:"PUT",body:JSON.stringify(body)});
    toast(s.name+" saved"+(up&&(body.memory!==s.memory||body.port!==s.port)?" · restart to apply":""),"ok");
    closeModal();load();
  });
  const del=btn("delete",async()=>{
    if(prompt("type "+s.name+" to delete it. a backup is kept")!==s.name)return;
    await api(s.name,{method:"DELETE"});
    toast("deleting "+s.name,"ok");closeModal();
    setTimeout(load,4000);
  },"danger");
  const h=el("div","mhead"),t=el("div","t",s.name);
  t.append(el("small",null,s.type+" "+s.version+(s.loader?" · loader "+s.loader:"")));
  h.append(t);
  const row=el("div","row");row.append(del,el("span","sp"),save);
  openModal(h,f,row);
}
buildNew();
load();setInterval(load,3000);
