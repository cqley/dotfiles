const $=(id)=>document.getElementById(id);
function el(t,c,x){const e=document.createElement(t);if(c)e.className=c;if(x!=null)e.textContent=x;return e;}
function img(src,c){const i=el("img",c);i.alt="";i.loading="lazy";if(src)i.src=src;return i;}
const head=(n)=>img("https://mc-heads.net/avatar/"+encodeURIComponent(n)+"/20","head");
const gb=(b)=>(b/1073741824).toFixed(1)+" GB";
const mbs=(b)=>b>1073741824?gb(b):b>1048576?(b/1048576).toFixed(1)+" MB":Math.ceil(b/1024)+" KB";
const num=(n)=>n>=1e6?(n/1e6).toFixed(1)+"M":n>=1e3?(n/1e3).toFixed(1)+"k":String(n);
const ms=(v)=>(+v).toFixed(1)+" ms";
function dur(t){const s=Math.max(0,Math.floor(t/1000));if(s<60)return s+"s";const m=Math.floor(s/60);if(m<60)return m+"m";const h=Math.floor(m/60);if(h<24)return h+"h "+(m%60)+"m";return Math.floor(h/24)+"d "+(h%24)+"h";}
const ago=(t)=>dur(Date.now()-t)+" ago";
const when=(t)=>new Date(t).toLocaleString(undefined,{day:"numeric",month:"short",hour:"2-digit",minute:"2-digit",hourCycle:"h23"});
function msg(t,err){const m=$("msg");m.textContent=t;m.className=err?"err":"";clearTimeout(msg.t);msg.t=setTimeout(()=>{m.textContent="";},err?8000:4000);}
async function api(path,opts){const r=await fetch("/api/"+path,opts);if(!r.ok)throw new Error((await r.text())||r.statusText);return r;}
const json=async(path)=>(await api(path)).json();
const post=(path,body)=>api(path,{method:"POST",body:body==null?undefined:typeof body==="string"?body:JSON.stringify(body)});
function btn(label,fn,cls){const b=el("button",cls,label);b.type="button";b.onclick=async()=>{b.disabled=true;try{await fn(b);}catch(e){msg(e.message,true);}b.disabled=false;};return b;}
function li(...nodes){const r=el("li");r.append(...nodes);return r;}
function phase(s){
  if(s.state==="active")return s.ready?"online":"starting";
  if(s.state==="activating")return "starting";
  if(s.state==="deactivating")return "stopping";
  if(s.state==="failed")return "failed";
  return "offline";
}
