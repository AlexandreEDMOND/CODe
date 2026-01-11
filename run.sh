#!/usr/bin/env bash
set -euo pipefail

GODOT_EXE="${GODOT_EXE:-godot}"
MODE="${1:-host}"
PORT=""

if [[ ! -d ".godot/imported" ]]; then
  "$GODOT_EXE" --path . --import
fi

if [[ "$MODE" == "host" ]]; then
  if [[ "${2:-}" == --port=* ]]; then
    PORT="${2#--port=}"
  elif [[ "${2:-}" =~ ^[0-9]+$ ]]; then
    PORT="${2}"
  fi
  LOCAL_IP=""
  if command -v hostname >/dev/null 2>&1; then
    LOCAL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -z "$LOCAL_IP" ]] && command -v ip >/dev/null 2>&1; then
    LOCAL_IP="$(ip -4 -o addr show scope global | awk 'NR==1{print $4}' | cut -d/ -f1)"
  fi
  if [[ -n "$LOCAL_IP" ]]; then
    echo "Host IP: $LOCAL_IP"
    echo "Join with: ./run.sh join $LOCAL_IP${PORT:+ $PORT}"
  else
    echo "Host IP not found. Use 'ip addr' to find your LAN IP."
  fi
  echo "Same PC: ./run.sh join 127.0.0.1${PORT:+ $PORT}"
  if [[ -n "$PORT" ]]; then
    "$GODOT_EXE" --path . -- --mode=host --port="$PORT"
  else
    "$GODOT_EXE" --path . -- --mode=host
  fi
  exit 0
fi

if [[ "$MODE" == "join" ]]; then
  IP="${2:-}"
  if [[ "${3:-}" == --port=* ]]; then
    PORT="${3#--port=}"
  elif [[ "${3:-}" =~ ^[0-9]+$ ]]; then
    PORT="${3}"
  fi
  if [[ -z "$IP" ]]; then
    echo "Usage: ./run.sh join 192.168.0.10"
    exit 1
  fi
  if [[ -n "$PORT" ]]; then
    "$GODOT_EXE" --path . -- --mode=join --ip="$IP" --port="$PORT"
  else
    "$GODOT_EXE" --path . -- --mode=join --ip="$IP"
  fi
  exit 0
fi

echo "Usage: ./run.sh <host|join> [ip]"
exit 1
