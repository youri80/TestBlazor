#!/bin/bash
# Smoke-Test der Blazor-App gegen einen laufenden Kestrel auf 127.0.0.1:5199
source /opt/data/home/.bashrc
cd "$(dirname "$0")"

PORT=5199
LOG="${TMPDIR:-/tmp}/blazor_run.log"

dotnet run --urls "http://127.0.0.1:$PORT" > "$LOG" 2>&1 &
PID=$!
echo "started pid=$PID"

for i in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)
  [ "$code" = "200" ] && break
  sleep 1
done
echo "ready after ${i}s (last status=$code)"

echo "=== status codes ==="
for p in / /counter /weather; do
  printf '%-10s ' "$p"
  curl -s -o "/tmp/page$(echo "$p" | tr -d /).html" -w '%{http_code}\n' "http://127.0.0.1:$PORT$p"
done

echo "=== home markers ==="
curl -s "http://127.0.0.1:$PORT/" -o /tmp/home.html
for s in "Hello, world!" "mud-layout" "mud-drawer" "mud-nav-link" "mud-button" "mud-card"; do
  printf '%-16s %s\n' "$s" "$(grep -c "$s" /tmp/home.html)"
done

echo "=== MudBlazor asset hrefs ==="
grep -oE '(href|src)="[^"]*MudBlazor[^"]*"' /tmp/home.html

echo "=== asset fetch (first css href) ==="
CSS=$(grep -oE 'href="[^"]*MudBlazor[^"]*\.css[^"]*"' /tmp/home.html | head -1 | sed 's/href="//;s/"$//')
echo "css url: $CSS"
curl -s -o /dev/null -w 'css status=%{http_code} bytes=%{size_download}\n' "http://127.0.0.1:$PORT/${CSS#/}"

echo "=== counter / weather markers ==="
curl -s "http://127.0.0.1:$PORT/counter" | grep -oE 'Current count: [0-9]+|Click me' | sort -u
curl -s "http://127.0.0.1:$PORT/weather" | grep -oE 'mud-table|mud-chip|Date|Summary' | sort -u

echo "=== server log tail ==="
tail -3 "$LOG"

kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
echo "stopped pid=$PID"
