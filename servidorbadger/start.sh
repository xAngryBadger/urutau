#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "========================================"
echo " Urutau - Servidor"
echo "========================================"

# Kill existing
pkill -f "pocketbase serve" 2>/dev/null || true
pkill -f "ngrok http 8090" 2>/dev/null || true
sleep 1

echo "[+] Iniciando PocketBase..."
./pocketbase serve --http=0.0.0.0:8090 &>/tmp/pb.log &
sleep 3

echo "[+] Iniciando ngrok..."
./ngrok http 8090 &>/tmp/ngrok.log &
sleep 5

echo "[+] Detectando URL publica..."
NGROK_URL=""
for i in $(seq 1 6); do
  NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null \
    | python3 -c "import sys,json; ts=json.load(sys.stdin)['tunnels']; print([t['public_url'] for t in ts if t['proto']=='https'][0])" 2>/dev/null || true)
  if [ -n "$NGROK_URL" ]; then break; fi
  echo "  Tentativa $i..."; sleep 3
done

echo ""
echo "========================================"
echo "   Servidor iniciado!"
echo "========================================"
echo ""
if [ -n "$NGROK_URL" ]; then
  echo "  URL publica: $NGROK_URL"
  echo ""
  echo "  Links para enviar:"
  echo "  -----------------------------"
  echo "  Admin (colega):  $NGROK_URL/urutau-admin/"
  echo "  PB Admin:        $NGROK_URL/_/"
  echo "  App (campo):     $NGROK_URL"
  echo "  Landing page:    $NGROK_URL/"
  echo "  -----------------------------"
else
  echo "  Nao foi possivel detectar URL automaticamente."
  echo "  Abra http://127.0.0.1:4040 no navegador para ver a URL."
  echo "  Local: http://localhost:8090"
fi
echo ""
echo "  Ctrl+C para parar o servidor..."
wait
