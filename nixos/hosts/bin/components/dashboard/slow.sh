paths="git:/srv/git files:/var/lib/linx-server music:/var/lib/navidrome puffer:/var/lib/pufferpanel public:/home/cat/public"

json=""
for p in $paths; do
  name="${p%%:*}"
  dir="${p#*:}"
  size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  [ -z "$size" ] && size="n/a"
  json="$json{\"name\":\"$name\",\"path\":\"$dir\",\"size\":\"$size\"},"
done
json="[${json%,}]"

cat > /var/lib/dash/storage.json <<eof
{"generated":$(date +%s),"components":$json}
eof
chmod 644 /var/lib/dash/storage.json
