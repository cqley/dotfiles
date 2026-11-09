const $=(id)=>document.getElementById(id);
const gb=(b)=>(b/1073741824).toFixed(1)+" GB";
const mbs=(b)=>b>1073741824?gb(b):b>1048576?(b/1048576).toFixed(1)+" MB":Math.ceil(b/1024)+" KB";
const num=(n)=>n>=1e6?(n/1e6).toFixed(1)+"M":n>=1e3?(n/1e3).toFixed(1)+"k":String(n);
const short=(t)=>new Date(t).toLocaleString(undefined,{day:"numeric",month:"short",hour:"2-digit",minute:"2-digit",hourCycle:"h23"});
function copyText(t){
  const a=el("textarea");a.value=t;a.readOnly=true;a.style.cssText="position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;font-size:16px;";
  document.body.append(a);a.focus();a.select();a.setSelectionRange(0,t.length);
  let ok=false;try{ok=document.execCommand("copy");}catch{}
  a.remove();
  if(!ok&&navigator.clipboard)navigator.clipboard.writeText(t).catch(()=>{});
  copyText.ok=ok||!!navigator.clipboard;
  return copyText.ok;
}
function dur(ms){const s=Math.max(0,Math.floor(ms/1000));if(s<60)return s+"s";const m=Math.floor(s/60);if(m<60)return m+"m";const h=Math.floor(m/60);if(h<24)return h+"h "+(m%60)+"m";return Math.floor(h/24)+"d "+(h%24)+"h";}
const ago=(t)=>dur(Date.now()-t);
function el(t,c,x){const e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e;}
function img(src,c){const i=el("img",c);i.loading="lazy";i.alt="";if(src)i.src=src;return i;}
const head=(n)=>img("https://mc-heads.net/avatar/"+encodeURIComponent(n)+"/20","head");
function toast(msg,kind){const d=el("div","toast "+(kind||""),msg);$("toasts").append(d);setTimeout(()=>{d.style.transition="opacity .3s";d.style.opacity="0";setTimeout(()=>d.remove(),300);},kind==="err"?6000:3000);}
function btn(label,fn,cls){
  const b=el("button",cls,label);
  b.onclick=async()=>{b.disabled=true;b.classList.add("busy");try{await fn(b);}catch(e){toast(e.message,"err");}finally{b.disabled=false;b.classList.remove("busy");}};
  return b;
}
function phase(s){
  if(s.state==="active")return s.ready?"online":"starting";
  if(s.state==="activating")return "starting";
  if(s.state==="deactivating")return "stopping";
  if(s.state==="failed")return "failed";
  return "offline";
}
function theme(){$("theme").title=document.documentElement.dataset.theme==="light"?"dark mode":"light mode";}
$("theme").onclick=()=>{
  const r=document.documentElement;
  r.dataset.theme=r.dataset.theme==="light"?"dark":"light";
  try{localStorage.setItem("theme",r.dataset.theme);}catch{}
  theme();
};
theme();
async function api(path,opts){
  const r=await fetch("/api/"+path,opts);
  if(!r.ok)throw new Error((await r.text())||r.statusText);
  return r;
}
const post=(path,body)=>api(path,{method:"POST",body:body==null?undefined:typeof body==="string"?body:JSON.stringify(body)});
