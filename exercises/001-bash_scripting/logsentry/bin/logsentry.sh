#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ===============
INPUT_FILE=""
FORMAT="text"
THRESHOLD=500
TOP_N=5
VERBOSE=0
INT_REGEX='^[0-9]+$'

# ===============
usage() {
  cat <<EOF
Usage: logsentry -i <file> [OPTIONS]

Options:
  -i, --input <file>       Fichier de logs (obligatoire)
  -f, --format <text|json> Format d'entrée (défaut: text)
  -t, --threshold <ms>     Seuil requête lente en ms (défaut: 500)
  -n, --top <N>            Nombre d'endpoints du top (défaut: 5)
  -v, --verbose            Mode verbeux
  -h, --help               Affiche cet aide
EOF
}

log_verbose() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

echo_err() {
  echo "Erreur : $*" >&2
}

# ===============
validate_args() {
  if [[ -z "$INPUT_FILE" ]]; then
    echo_err "L'option -i/--input est obligatoire."
    usage >&2
    exit 1
  fi

  if [[ ! -f "$INPUT_FILE" || ! -r "$INPUT_FILE" ]]; then
    echo_err "Fichier '$INPUT_FILE' introuvable ou illisible."
    exit 2
  fi

  if [[ ! -s "$INPUT_FILE" ]]; then
    echo_err "Le fichier '$INPUT_FILE' est vide."
    exit 4
  fi

  if [[ "$FORMAT" != "text" && "$FORMAT" != "json" ]]; then
    echo_err "Format '$FORMAT' non supporté (text|json uniquement)."
    exit 3
  fi

  if ! [[ "$TOP_N" =~ $INT_REGEX ]]; then
    echo_err "--top/-n doit être un entier positif."
    exit 1
  fi

  if ! [[ "$THRESHOLD" =~ $INT_REGEX ]]; then
    echo_err "--threshold/-t doit être un entier positif."
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -i | --input)
      INPUT_FILE="${2:-}"
      shift 2
      ;;
    -f | --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    -t | --threshold)
      THRESHOLD="${2:-}"
      shift 2
      ;;
    -n | --top)
      TOP_N="${2:-}"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      echo_err "Option inconnue '$1'"
      usage >&2
      exit 1
      ;;
    esac
  done
}

# ===============
analyze_text() {
  LC_ALL=C awk -v threshold="$THRESHOLD" -v top_n="$TOP_N" -v filename="$INPUT_FILE" '
  {
    req++
    lat = $6 + 0
    total_lat += lat
    if (lat > threshold) slow++

    if ($5 >= 500 && $5 <= 599) {
      errors++
      ip_err[$2] = 1
    }
    endpoints[$4]++
  }
  END {
    if (req == 0) exit 4

    avg_lat = total_lat / req
    err_pct = (errors / req) * 100

    ip_str = ""
    for (ip in ip_err) {
      ip_str = (ip_str == "") ? ip : ip_str ", " ip
    }

    printf "Fichier         : %s\n", filename
    printf "Requêtes        : %d\n", req
    printf "Erreurs 5xx     : %d (%.2f%%)\n", errors, err_pct
    printf "Latence moy.    : %.0f ms\n", avg_lat
    printf "Lentes (>%dms) : %d\n", threshold, slow
    printf "IPs en erreur   : %s\n\n", (ip_str != "" ? ip_str : "Aucune")
    printf "Top %d endpoints:\n", top_n

    cmd = "sort -k2,2nr | head -n " top_n
    for (path in endpoints) {
      pct = (endpoints[path] / req) * 100
      printf "  %-25s %d (%.2f%%)\n", path, endpoints[path], pct | cmd
    }
    close(cmd)
  }' "$INPUT_FILE"
}

analyze_json() {
  jq -s \
    --arg file "$INPUT_FILE" \
    --argjson threshold "$THRESHOLD" \
    --argjson top_n "$TOP_N" '
    if length == 0 then
      halt_error(4)
    else
      map(. + {clean_ms: (.duration_ms | tostring | gsub("[^0-9]"; "") | tonumber)}) as $data |

      ($data | length) as $req |
      ($data | map(select(.status >= 500 and .status <= 599)) | length) as $err |
      ($data | map(.clean_ms) | add / $req) as $avg_lat |
      ($data | map(select(.clean_ms > $threshold)) | length) as $slow |
      ($data | group_by(.path) | map({path: .[0].path, count: length}) | sort_by(-.count)[:$top_n]) as $top |

      {
        file: $file,
        requests: $req,
        error_rate: (($err / $req * 10000 | round) / 100),
        avg_latency_ms: ($avg_lat | round),
        slow_requests: $slow,
        top_endpoints: $top
      }
    end
  ' "$INPUT_FILE"
}

# ===============
main() {
  parse_args "$@"
  validate_args

  log_verbose "Fichier: $INPUT_FILE | Format: $FORMAT | Threshold: $THRESHOLD | Top: $TOP_N"

  if [[ "$FORMAT" == "json" ]]; then
    analyze_json
  else
    analyze_text
  fi
}

# ===============
main "$@"
