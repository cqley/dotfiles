export LC_ALL=C

paths="files:/var/lib/linx music:/var/lib/navidrome matrix:/var/lib/tuwunel puffer:/var/lib/pufferpanel blog:/var/lib/blog photos:/var/lib/immich public:/home/cat/public"

json=""
for p in $paths; do
  name="${p%%:*}"
  dir="${p#*:}"
  bytes=$(du -sbL "$dir" 2>/dev/null | cut -f1)
  [ -z "$bytes" ] && bytes=0
  json="$json{\"name\":\"$name\",\"path\":\"$dir\",\"bytes\":$bytes},"
done
json="[${json%,}]"

cat > /var/lib/dash/storage.json <<eof
{"generated":$(date +%s),"components":$json}
eof
chmod 644 /var/lib/dash/storage.json
