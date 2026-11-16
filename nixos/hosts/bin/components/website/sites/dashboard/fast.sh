units="nginx.service tuwunel.service livekit.service lk-jwt-service.service coturn.service navidrome.service downloader.service edeltalk.timer unfassbar.timer henkescorner.timer wanshow.timer blog.service share.service notes.service immich-server.service minecraft-cron.timer mcpanel.service syncthing.service wireguard-wg0.service fcgiwrap-git.socket sshd.service fail2ban.service"
units="$units $(systemctl list-units --all --plain --no-legend 'minecraft@*.service' 2>/dev/null | awk '{print $1}')"

read -r l1 l5 l15 _ < /proc/loadavg
mem_total=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))

svc_json=""
for u in $units; do
  active=$(systemctl is-active "$u" 2>/dev/null || true)
  failed=$(systemctl is-failed "${u%.*}.service" 2>/dev/null || true)
  errs=$(journalctl -u "${u%.*}.service" -p err --since "-10min" --no-pager -q 2>/dev/null | wc -l)
  [ "$u" = sshd.service ] && errs=0
  name="${u%.*}"
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

since=$(date -d '-7 days' +%s)
events=$(
{
  journalctl -u sshd -S @"$since" -q --no-pager -o short-unix | grep 'Accepted publickey' |
    awk 'NR == FNR { k[$1] = $2; next } { for (i = 1; i <= NF; i++) { if ($i == "for") u = $(i + 1); if ($i == "from") ip = $(i + 1); if ($i ~ /^SHA256:/) f = $i } d = f in k ? k[f] : "unknown"; sub(/^.*@/, "", d); printf "%d\tssh\t%s\t%s\t%s\n", $1, u, d, ip }' \
      <(cat /etc/ssh/authorized_keys.d/* | ssh-keygen -lf - | awk '{ print $2, $3 }') -
  journalctl -S @"$since" -q --no-pager -o short-unix SYSLOG_IDENTIFIER=doas |
    awk '{ m = $0; sub(/^[^:]*: /, "", m) } m ~ / ran command / { u = m; sub(/ .*/, "", u); c = m; sub(/^[^ ]* ran command /, "", c); sub(/ as root from .*$/, "", c); printf "%d\tdoas\t%s\t%s\t\n", $1, u, c } m ~ /^failed auth for / { printf "%d\tdoas\t%s\tfailed\t\n", $1, $NF }'
} | sort -rn | head -n 25)

today=$(journalctl -u sshd -S today -q --no-pager -o cat)
conns=$(grep -c '^Connection from ' <<< "$today" || true)
okays=$(grep -c '^Accepted publickey' <<< "$today" || true)
ips=$(awk '/^Connection from / { print $3 }' <<< "$today" | sort -u | wc -l)
banned=$(journalctl -u fail2ban -S -30d -q --no-pager -o cat | awk '{ for (i = 1; i < NF; i++) { if ($i == "Unban") delete b[$(i + 1)]; else if ($i == "Ban") b[$(i + 1)] = 1 } } END { n = 0; for (x in b) n++; print n }')

devices=$(join <(wg show wg0 allowed-ips | sort) <(join <(wg show wg0 endpoints | sort) <(wg show wg0 latest-handshakes | sort)) |
  while read -r key allowed endpoint seen; do
    ip=${allowed%%/*}
    from=${endpoint%:*}
    from=${from#[}
    from=${from%]}
    name=$(getent hosts "$ip" | awk '{ print $2 }')
    printf '%s\t%s\t%s\n' "${name:-$ip}" "$from" "$seen"
  done)

jq -n --arg events "$events" --arg devices "$devices" \
  --argjson conns "$conns" --argjson okays "$okays" --argjson ips "$ips" --argjson banned "$banned" '
  def rows($s): $s | split("\n") | map(select(length > 0) | split("\t"));
  {
    generated: now | floor,
    events: rows($events) | map({ t: (.[0] | tonumber), kind: .[1], user: .[2], what: .[3], ip: .[4] }),
    failed: { today: ($conns - $okays), ips: $ips },
    banned: $banned,
    devices: rows($devices) | map({ name: .[0], ip: (if .[1] == "(none)" then null else .[1] end), seen: (.[2] | tonumber) })
  }' > /var/lib/dash/logins.json.part
mv /var/lib/dash/logins.json.part /var/lib/dash/logins.json
chmod 644 /var/lib/dash/logins.json
