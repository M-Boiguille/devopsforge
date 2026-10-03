#!/usr/bin/env bash
# fil-rouge/logsentry/bin/logsentry.sh — v0.3.0 (mode streaming)
# ⚠️  VERSION DÉFECTUEUSE — ne pas réécrire, diagnostiquer puis réparer.

set -euo pipefail

INPUT=""
FORMAT="text"
TOP_N=10
COUNT=0
declare -A ENDPOINTS

usage() {
  cat >&2 <<EOF
usage: $0 -i <fichier|-> [-f text|json] [-n N]
  -i   fichier d'entrée, ou '-' pour stdin
  -f   format de sortie : text (défaut) | json
  -n   nombre de top endpoints (défaut 10)
EOF
}

cleanup() {
  echo "cleanup: terminaison propre"
  rm -f "/tmp/logsentry.$$"
}

on_term() {
  exit 143
}

trap cleanup EXIT
trap on_term TERM

while getopts "i:f:n:h" opt; do
  case "$opt" in
  i) INPUT="$OPTARG" ;;
  f) FORMAT="$OPTARG" ;;
  n) TOP_N="$OPTARG" ;;
  h)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
  esac
done

if [[ -z "$INPUT" || "$INPUT" == "-" ]]; then
  STREAM="/dev/stdin"
else
  STREAM="$INPUT"
fi

while read -r _ _ _ _ _ _ endpoint _; do
  COUNT=$((COUNT + 1))
  ENDPOINTS["$endpoint"]=$((${ENDPOINTS["$endpoint"]:-0} + 1))
done <"$STREAM"

if [[ "$FORMAT" == "json" ]]; then
  printf '{"count": %s}\n' "$COUNT"
else
  printf 'count=%s\n' "$COUNT"
fi
