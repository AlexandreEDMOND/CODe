#!/usr/bin/env bash
set -euo pipefail

GODOT_EXE="${GODOT_EXE:-godot}"
MODE="${1:-host}"

if [[ ! -d ".godot/imported" ]]; then
  "$GODOT_EXE" --path . --import
fi

if [[ "$MODE" == "host" ]]; then
  "$GODOT_EXE" --path . -- --mode=host
  exit 0
fi

if [[ "$MODE" == "join" ]]; then
  IP="${2:-}"
  if [[ -z "$IP" ]]; then
    echo "Usage: ./run.sh join 192.168.0.10"
    exit 1
  fi
  "$GODOT_EXE" --path . -- --mode=join --ip="$IP"
  exit 0
fi

echo "Usage: ./run.sh <host|join> [ip]"
exit 1
