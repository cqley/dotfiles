{ config, pkgs, lib, ... }:

let
  indexHtml = pkgs.writeText "index.html" ''
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>ttv</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/hls.js/1.5.13/hls.min.js"></script>
    <style>
    :root{--bg:#0e0e10;--fg:#efeff1;--acc:#ffb6c1;--dim:#1f1f23}
    *{box-sizing:border-box;margin:0}
    body{background:var(--bg);color:var(--fg);font:14px monospace;height:100vh;display:flex;flex-direction:column}
    #bar{display:flex;gap:8px;padding:8px}
    input{flex:1;background:var(--dim);border:1px solid #333;color:var(--fg);padding:8px;font:inherit}
    button{background:var(--acc);border:0;color:#111;padding:8px 12px;cursor:pointer;font:inherit;font-weight:bold}
    select{background:var(--dim);color:var(--fg);border:1px solid #333;font:inherit}
    #favbar{display:flex;gap:6px;padding:0 8px 8px;flex-wrap:wrap}
    #favbar button{background:var(--dim);border:1px solid #333;color:var(--fg);font-weight:normal}
    #meta{display:flex;justify-content:space-between;padding:4px 8px;opacity:.7;gap:8px}
    #main{flex:1;display:flex;min-height:0}
    video{flex:1;background:#000;min-width:0}
    #chat{width:280px;background:var(--dim);overflow-y:auto;padding:4px 8px;font-size:12px}
    #chat div{margin:2px 0;word-wrap:break-word}
    </style>
    </head>
    <body>
    <div id="bar">
    <input id="ch" placeholder="channel name" autofocus>
    <select id="q"><option value="-1">auto</option></select>
    <button id="fav">★</button>
    <button id="go">watch</button>
    </div>
    <div id="favbar"></div>
    <div id="meta"><span id="status"></span><span id="title"></span></div>
    <div id="main">
    <video id="v" controls autoplay></video>
    <div id="chat"></div>
    </div>
    <script>
    const v=document.getElementById('v')
    const st=document.getElementById('status')
    const ttl=document.getElementById('title')
    const ch=document.getElementById('ch')
    const q=document.getElementById('q')
    const chatbox=document.getElementById('chat')
    const favbar=document.getElementById('favbar')
    let hls,ws,current

    function favs(){return JSON.parse(localStorage.getItem('favs')||'[]')}
    function toggleFav(login){
      let f=favs()
      f=f.includes(login)?f.filter(x=>x!==login):[...f,login]
      localStorage.setItem('favs',JSON.stringify(f))
      renderFavs()
    }
    function renderFavs(){
      favbar.innerHTML=""
      favs().forEach(f=>{
        const b=document.createElement('button')
        b.textContent=f
        b.onclick=()=>{ch.value=f;watch(f)}
        favbar.appendChild(b)
      })
    }

    function chat(login){
      if(ws)ws.close()
      chatbox.innerHTML=""
      ws=new WebSocket('wss://irc-ws.chat.twitch.tv:443')
      ws.onopen=()=>{
        ws.send('CAP REQ :twitch.tv/tags')
        ws.send('NICK justinfan'+Math.floor(Math.random()*99999))
        ws.send('JOIN #'+login)
      }
      ws.onmessage=e=>{
        e.data.split('\r\n').forEach(line=>{
          if(line.startsWith('PING')){ws.send('PONG :tmi.twitch.tv');return}
          if(!line.includes('PRIVMSG'))return
          const tagm=line.match(/display-name=([^;]*)/)
          const colm=line.match(/color=(#[0-9a-fA-F]{6})/)
          const user=(tagm&&tagm[1])||'anon'
          const color=(colm&&colm[1])||'#bbb'
          const msg=line.split('PRIVMSG #'+login+' :')[1]||""
          const d=document.createElement('div')
          const b=document.createElement('b')
          b.style.color=color
          b.textContent=user
          d.appendChild(b)
          d.appendChild(document.createTextNode(': '+msg))
          chatbox.appendChild(d)
          chatbox.scrollTop=chatbox.scrollHeight
        })
      }
    }

    async function info(login){
      try{
        const r=await fetch('/info?channel='+login)
        const j=await r.json()
        const s=j&&j.stream
        ttl.textContent=s?(s.title+' · '+s.viewers+' viewers'):""
      }catch(e){ttl.textContent=""}
    }

    async function watch(login){
      current=login
      st.textContent='loading '+login+'...'
      ttl.textContent=""
      q.innerHTML='<option value="-1">auto</option>'
      try{
        const url='/usher?channel='+login
        if(hls)hls.destroy()
        if(Hls.isSupported()){
          hls=new Hls()
          hls.loadSource(url)
          hls.attachMedia(v)
          hls.on(Hls.Events.ERROR,(e,d)=>{if(d.fatal)st.textContent='error: '+d.type})
          hls.on(Hls.Events.MANIFEST_PARSED,()=>{
            st.textContent='live: '+login
            v.play()
            hls.levels.forEach((l,i)=>{
              const o=document.createElement('option')
              o.value=i
              o.textContent=(l.attrs&&l.attrs.NAME)||l.height+'p'
              q.appendChild(o)
            })
          })
        }else{
          v.src=url
        }
        history.replaceState(null,"",'?c='+login)
      }catch(e){st.textContent='error: '+e.message}
      chat(login)
      info(login)
    }

    q.onchange=()=>{hls.currentLevel=+q.value}
    document.getElementById('go').onclick=()=>watch(ch.value.trim().toLowerCase())
    document.getElementById('fav').onclick=()=>{if(current)toggleFav(current)}
    ch.onkeydown=e=>{if(e.key==='Enter')watch(ch.value.trim().toLowerCase())}

    renderFavs()
    const p=new URLSearchParams(location.search).get('c')
    if(p){ch.value=p;watch(p)}
    </script>
    </body>
    </html>
  '';

  serverPy = pkgs.writeScriptBin "ttv-server" ''
    #!${pkgs.python3}/bin/python3
    import json, urllib.request, urllib.parse
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    cid='kimne78kx3ncx6brgo4mv6wki5h1ko'
    sha='0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712'
    ua='Mozilla/5.0'

    def fetch(url):
        req=urllib.request.Request(url,headers={'User-Agent':ua})
        with urllib.request.urlopen(req) as r:
            return r.read(), r.headers.get('Content-Type',"")

    def token(login):
        body=json.dumps({
            'operationName':'PlaybackAccessToken',
            'variables':{'isLive':True,'login':login,'isVod':False,'vodID':"",'playerType':'site'},
            'extensions':{'persistedQuery':{'version':1,'sha256Hash':sha}}
        }).encode()
        req=urllib.request.Request('https://gql.twitch.tv/gql',data=body,headers={'Client-Id':cid,'Content-Type':'text/plain','User-Agent':ua})
        with urllib.request.urlopen(req) as r:
            return json.load(r)['data']['streamPlaybackAccessToken']

    def rewrite(text):
        out=[]
        for line in text.decode().splitlines():
            if line.startswith('http'):
                out.append('/relay?u='+urllib.parse.quote(line,safe=""))
            else:
                out.append(line)
        return '\n'.join(out).encode()

    def stream_info(login):
        q='query{user(login:"'+login+'"){stream{title viewersCount}}}'
        body=json.dumps({'query':q}).encode()
        req=urllib.request.Request('https://gql.twitch.tv/gql',data=body,headers={'Client-Id':cid,'Content-Type':'application/json','User-Agent':ua})
        with urllib.request.urlopen(req) as r:
            j=json.load(r)
        s=j.get('data',{}).get('user',{})
        s=s.get('stream') if s else None
        if not s:
            return {'stream':None}
        return {'stream':{'title':s['title'],'viewers':s['viewersCount']}}

    def master(login):
        t=token(login)
        if not t:
            return None
        url=f"https://usher.ttvnw.net/api/channel/hls/{login}.m3u8?client_id={cid}&token={urllib.parse.quote(t['value'])}&sig={t['signature']}&allow_source=true&fast_bread=true"
        data,_=fetch(url)
        return rewrite(data)

    class h(BaseHTTPRequestHandler):
        def send(self,status,ctype,data):
            self.send_response(status)
            self.send_header('Access-Control-Allow-Origin','*')
            self.send_header('Content-Type',ctype)
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            parsed=urllib.parse.urlparse(self.path)
            qs=urllib.parse.parse_qs(parsed.query)
            path=parsed.path

            if path in ('/','/index.html'):
                with open('${indexHtml}','rb') as f:
                    self.send(200,'text/html',f.read())
            elif path=='/info':
                login=qs.get('channel',[""])[0]
                try:
                    data=json.dumps(stream_info(login)).encode()
                except Exception:
                    data=json.dumps({'stream':None}).encode()
                self.send(200,'application/json',data)
            elif path=='/usher':
                login=qs.get('channel',[""])[0]
                try:
                    data=master(login)
                except Exception:
                    data=None
                self.send(200 if data else 404,'application/vnd.apple.mpegurl',data or b"")
            elif path=='/relay':
                url=qs.get('u',[""])[0]
                try:
                    data,ctype=fetch(url)
                except Exception:
                    self.send(502,'text/plain',b"")
                    return
                if b'#EXTM3U' in data[:20]:
                    data=rewrite(data)
                    ctype='application/vnd.apple.mpegurl'
                self.send(200,ctype or 'application/octet-stream',data)
            else:
                self.send(404,'text/plain',b"")

        def log_message(self,*a): pass

    if __name__=='__main__':
        ThreadingHTTPServer(('0.0.0.0',8934),h).serve_forever()
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 8934 ];

  systemd.services.ttv = {
    description = "Lightweight Twitch Client";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${serverPy}/bin/ttv-server";
      Restart = "always";
      DynamicUser = true;
    };
  };
}