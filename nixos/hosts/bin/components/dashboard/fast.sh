units="nginx.service navidrome.service music-web.service edeltalk.service unfassbar.service pufferpanel.service linx-server.service wireguard-wg0.service sshd.service syncthing.service"
cgit_unit=$(systemctl list-units --plain --no-legend 'fcgiwrap-cgit-*' 2>/dev/null | awk '{print $1}' | head -n1)
[ -n "$cgit_unit" ] && units="$units $cgit_unit"

read -r l1 l5 l15 _ < /proc/loadavg
mem_total=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))

svc_json=""
for u in $units; do
  active=$(systemctl is-active "$u" 2>/dev/null || true)
  failed=$(systemctl is-failed "$u" 2>/dev/null || true)
  errs=$(journalctl -u "$u" -p err --since "-10min" --no-pager -q 2>/dev/null | wc -l)
  name="${u%.service}"
  svc_json="$svc_json{\"name\":\"$name\",\"active\":\"$active\",\"failed\":\"$failed\",\"errors\":$errs},"
done
svc_json="[${svc_json%,}]"

df_json=""
while read -r tgt size used pct; do
  pct=${pct%\%}
  df_json="$df_json{\"path\":\"$tgt\",\"size\":\"$size\",\"used\":\"$used\",\"pct\":$pct},"
done < <(df -h --output=target,size,used,pcent -x tmpfs -x devtmpfs | tail -n +2)
df_json="[${df_json%,}]"

cat > /var/lib/dash/status.json <<eof
{"generated":$(date +%s),"load":[$l1,$l5,$l15],"mem":{"total":$mem_total,"used":$mem_used},"disk":$df_json,"services":$svc_json}
eof
chmod 644 /var/lib/dash/status.json
