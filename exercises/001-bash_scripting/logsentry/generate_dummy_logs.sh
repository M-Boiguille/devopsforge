#!/bin/bash

FILENAME="access"

if [ "$#" == 1 ]; then
  FILENAME="$1"
fi

{
  for _ in $(seq 1 500); do
    ip="10.0.0.$(((RANDOM % 8) + 10))"
    method=$(printf '%s ' GET POST GET GET DELETE | cut -d' ' -f$(((RANDOM % 4) + 1)))
    path=$(printf '%s ' /api/users /api/orders /health /api/users/42 /api/payments | cut -d' ' -f$(((RANDOM % 5) + 1)))
    status=$(printf '%s ' 200 200 200 201 404 500 503 | cut -d' ' -f$(((RANDOM % 7) + 1)))
    ms=$((RANDOM % 1200))
    printf '2024-06-01T08:%02d:%02dZ %s %s %s %s %dms\n' $((RANDOM % 60)) $((RANDOM % 60)) "$ip" "$method" "$path" "$status" "$ms"
  done
} >"$FILENAME".log

while read -r ts ip method path status ms; do
  printf '{"ts":"%s","ip":"%s","method":"%s","path":"%s","status":%s,"duration_ms":%s}\n' \
    "$ts" "$ip" "$method" "$path" "$status" "${ms%dms}"
done </data/"$FILENAME".log >/data/"$FILENAME".jsonl
