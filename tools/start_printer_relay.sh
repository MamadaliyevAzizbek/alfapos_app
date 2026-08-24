#!/bin/bash
# ALFAPOS mobil printer relay — Mac USB printer uchun fon xizmati.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${ALFAPOS_RELAY_PORT:-9100}"
cd "$ROOT"

is_listening() {
  lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

print_status() {
  echo "Printer relay port $PORT:"
  lsof -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || echo "  (hech narsa tinglamayapti)"
}

if [[ "${1:-}" == "--status" ]]; then
  print_status
  exit 0
fi

if [[ "${1:-}" == "--stop" ]]; then
  pids=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
  if [[ -z "${pids:-}" ]]; then
    echo "Relay allaqachon o‘chirilgan (port $PORT bo‘sh)."
    exit 0
  fi
  echo "To‘xtatilmoqda: $pids"
  kill $pids 2>/dev/null || true
  sleep 1
  print_status
  exit 0
fi

if is_listening; then
  if [[ "${1:-}" == "--restart" ]]; then
    echo "Eski relay to‘xtatilmoqda..."
    "$0" --stop
  else
    echo "Relay allaqachon ishlayapti (port $PORT band)."
    print_status
    echo ""
    echo "Qayta ishga tushirish: $0 --restart"
    echo "To‘xtatish:           $0 --stop"
    exit 0
  fi
fi

echo "Relay ishga tushmoqda: 0.0.0.0:$PORT"
exec python3 tools/printer_tcp_relay.py
