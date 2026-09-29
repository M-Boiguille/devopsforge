#!/usr/bin/env bash

set -uo pipefail

###############################################################################
# Configuration
###############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

APP="$PROJECT_DIR/bin/logsentry.sh"
DATA_DIR="$PROJECT_DIR/data"

LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/test_${TIMESTAMP}.log"

IMAGE="${IMAGE:-logsentry:test}"

PASS=0
FAIL=0
SKIP=0

TMP_DIR="$(mktemp -d)"

###############################################################################
# Cleanup
###############################################################################

cleanup() {
  rm -rf -- "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"

###############################################################################
# Colors
###############################################################################

green() {
  printf '\033[32m%s\033[0m' "$1"
}

red() {
  printf '\033[31m%s\033[0m' "$1"
}

yellow() {
  printf '\033[33m%s\033[0m' "$1"
}

blue() {
  printf '\033[34m%s\033[0m' "$1"
}

###############################################################################
# Logging
###############################################################################

log() {
  printf '%s\n' "$1" >>"$LOG_FILE"
}

log_command() {
  log "COMMAND:"
  log "  $1"
}

log_output() {
  local output="$1"

  log "OUTPUT:"

  if [[ -n "$output" ]]; then
    log "$output"
  else
    log "(no output)"
  fi
}

###############################################################################
# Test helpers
###############################################################################

run_test() {
  local name="$1"
  shift

  local output
  local status
  local command

  command="$(printf '%q ' "$@")"
  command="${command% }"

  printf '  %-65s ' "$name"

  log ""
  log "================================================================"
  log "TEST: $name"
  log "================================================================"
  log_command "$command"

  output="$("$@" 2>&1)"
  status=$?

  log_output "$output"
  log "EXIT CODE: $status"

  if [[ "$status" -eq 0 ]]; then
    printf '%s\n' "$(green "PASS")"
    log "RESULT: PASS"

    PASS=$((PASS + 1))
    return 0
  fi

  printf '%s\n' "$(red "FAIL")"
  log "RESULT: FAIL"

  printf '    exit: %s\n' "$status"

  if [[ -n "$output" ]]; then
    printf '    output:\n'
    printf '%s\n' "$output" | sed 's/^/      /'
  fi

  FAIL=$((FAIL + 1))
  return 1
}

run_test_with_expected_exit() {
  local name="$1"
  local expected="$2"
  shift 2

  local output
  local status
  local command

  command="$(printf '%q ' "$@")"
  command="${command% }"

  printf '  %-65s ' "$name"

  log ""
  log "================================================================"
  log "TEST: $name"
  log "EXPECTED EXIT CODE: $expected"
  log "================================================================"
  log_command "$command"

  output="$("$@" 2>&1)"
  status=$?

  log_output "$output"
  log "ACTUAL EXIT CODE: $status"

  if [[ "$status" -eq "$expected" ]]; then
    printf '%s\n' "$(green "PASS")"
    log "RESULT: PASS"

    PASS=$((PASS + 1))
    return 0
  fi

  printf '%s\n' "$(red "FAIL")"
  log "RESULT: FAIL"

  printf '    expected exit: %s\n' "$expected"
  printf '    actual exit  : %s\n' "$status"

  if [[ -n "$output" ]]; then
    printf '    output:\n'
    printf '%s\n' "$output" | sed 's/^/      /'
  fi

  FAIL=$((FAIL + 1))
  return 1
}

run_shell_test() {
  local name="$1"
  local command="$2"

  local output
  local status

  printf '  %-65s ' "$name"

  log ""
  log "================================================================"
  log "TEST: $name"
  log "================================================================"
  log_command "$command"

  output="$(bash -c "$command" 2>&1)"
  status=$?

  log_output "$output"
  log "EXIT CODE: $status"

  if [[ "$status" -eq 0 ]]; then
    printf '%s\n' "$(green "PASS")"
    log "RESULT: PASS"

    PASS=$((PASS + 1))
    return 0
  fi

  printf '%s\n' "$(red "FAIL")"
  log "RESULT: FAIL"

  printf '    exit: %s\n' "$status"

  if [[ -n "$output" ]]; then
    printf '    output:\n'
    printf '%s\n' "$output" | sed 's/^/      /'
  fi

  FAIL=$((FAIL + 1))
  return 1
}

skip_test() {
  local name="$1"
  local reason="$2"

  printf '  %-65s %s\n' "$name" "$(yellow "SKIP")"

  log ""
  log "================================================================"
  log "TEST: $name"
  log "================================================================"
  log "RESULT: SKIP"
  log "REASON: $reason"

  SKIP=$((SKIP + 1))
}

section() {
  printf '\n%s\n' "$(blue "=== $1 ===")"

  log ""
  log "################################################################"
  log "# $1"
  log "################################################################"
}

###############################################################################
# Header
###############################################################################

printf '%s\n' "$(blue "Logsentry test suite")"
printf 'Project : %s\n' "$PROJECT_DIR"
printf 'Binary  : %s\n' "$APP"
printf 'Image   : %s\n' "$IMAGE"
printf 'Log     : %s\n' "$LOG_FILE"
printf '\n'

log "================================================================"
log "LOGSENTRY TEST SUITE"
log "================================================================"
log "Started: $(date)"
log "Project: $PROJECT_DIR"
log "Binary: $APP"
log "Docker image: $IMAGE"

###############################################################################
# PROJECT / PREREQUISITES
###############################################################################

section "PROJECT / PREREQUISITES"

run_test \
  "logsentry.sh exists" \
  test -f "$APP"

run_test \
  "logsentry.sh is executable" \
  test -x "$APP"

run_test \
  "text fixture exists" \
  test -f "$DATA_DIR/access.log"

run_test \
  "JSONL fixture exists" \
  test -f "$DATA_DIR/access.jsonl"

if command -v shellcheck >/dev/null 2>&1; then
  run_test \
    "ShellCheck" \
    shellcheck -S warning "$APP"
else
  skip_test \
    "ShellCheck" \
    "shellcheck is not installed"
fi

if command -v jq >/dev/null 2>&1; then
  run_test \
    "jq available" \
    jq --version
else
  skip_test \
    "jq" \
    "jq is not installed"
fi

if command -v docker >/dev/null 2>&1; then
  run_test \
    "Docker available" \
    docker version
else
  skip_test \
    "Docker" \
    "docker is not installed"
fi

###############################################################################
# LOCAL / HELP
###############################################################################

section "LOCAL / HELP"

run_test_with_expected_exit \
  "short help" \
  0 \
  "$APP" -h

run_test_with_expected_exit \
  "long help" \
  0 \
  "$APP" --help

###############################################################################
# LOCAL / TEXT
###############################################################################

section "LOCAL / TEXT"

run_test_with_expected_exit \
  "default text format" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log"

run_test_with_expected_exit \
  "explicit text format" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -f text

run_test_with_expected_exit \
  "long options" \
  0 \
  "$APP" \
  --input "$DATA_DIR/access.log" \
  --format text \
  --threshold 500 \
  --top 5

run_test_with_expected_exit \
  "custom threshold" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -t 800

run_test_with_expected_exit \
  "custom top" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n 3

run_test_with_expected_exit \
  "verbose" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -v

run_test_with_expected_exit \
  "all options combined" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -f text \
  -t 800 \
  -n 3 \
  -v

###############################################################################
# LOCAL / TEXT OUTPUT
###############################################################################

section "LOCAL / TEXT OUTPUT"

# Ce test est volontairement présent pour avoir la sortie complète
# du programme dans le fichier de log.
run_test \
  "display complete text output" \
  "$APP" \
  -i "$DATA_DIR/access.log"

# Les tests suivants vérifient uniquement les éléments contractuels.
#
# Si les libellés exacts de ton assignment sont différents, adapte
# uniquement ces assertions.

run_shell_test \
  "text output contains request information" \
  "'$APP' -i '$DATA_DIR/access.log' | grep -Eqi 'requêtes'"

run_shell_test \
  "text output contains error rate information" \
  "'$APP' -i '$DATA_DIR/access.log' | grep -Eqi 'erreurs.*5xx|%'"

run_shell_test \
  "text output contains latency information" \
  "'$APP' -i '$DATA_DIR/access.log' | grep -Eqi 'latence'"

run_shell_test \
  "text output contains slow request information" \
  "'$APP' -i '$DATA_DIR/access.log' | grep -Eqi 'lentes'"

run_shell_test \
  "text output contains endpoint information" \
  "'$APP' -i '$DATA_DIR/access.log' | grep -Eqi 'endpoints'"

###############################################################################
# LOCAL / JSON
###############################################################################

section "LOCAL / JSON"

run_test_with_expected_exit \
  "JSON format" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.jsonl" \
  -f json

run_test_with_expected_exit \
  "JSON with threshold" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.jsonl" \
  -f json \
  -t 800

run_test_with_expected_exit \
  "JSON with top" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.jsonl" \
  -f json \
  -n 3

run_test \
  "display complete JSON output" \
  "$APP" \
  -i "$DATA_DIR/access.jsonl" \
  -f json

run_shell_test \
  "JSON is valid" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e . >/dev/null"

run_shell_test \
  "JSON contains file" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.file' >/dev/null"

run_shell_test \
  "JSON contains requests" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.requests' >/dev/null"

run_shell_test \
  "JSON contains error_rate" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.error_rate' >/dev/null"

run_shell_test \
  "JSON contains avg_latency_ms" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.avg_latency_ms' >/dev/null"

run_shell_test \
  "JSON contains slow_requests" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.slow_requests' >/dev/null"

run_shell_test \
  "JSON contains top_endpoints" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.top_endpoints' >/dev/null"

run_shell_test \
  "JSON endpoint has path" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.top_endpoints[0].path' >/dev/null"

run_shell_test \
  "JSON endpoint has count" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json | jq -e '.top_endpoints[0].count' >/dev/null"

###############################################################################
# LOCAL / STDIN
###############################################################################

section "LOCAL / STDIN"

run_shell_test \
  "text through stdin with -i -" \
  "cat '$DATA_DIR/access.log' | '$APP' -i -"

run_shell_test \
  "JSON through stdin with -i -" \
  "cat '$DATA_DIR/access.jsonl' | '$APP' -i - -f json | jq -e . >/dev/null"

###############################################################################
# LOCAL / INVALID ARGUMENTS
###############################################################################

section "LOCAL / INVALID ARGUMENTS"

run_test_with_expected_exit \
  "missing input" \
  1 \
  "$APP"

run_test_with_expected_exit \
  "missing argument after -i" \
  1 \
  "$APP" -i

run_test_with_expected_exit \
  "missing argument after --input" \
  1 \
  "$APP" --input

run_test_with_expected_exit \
  "missing argument after -f" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -f

run_test_with_expected_exit \
  "missing argument after -t" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -t

run_test_with_expected_exit \
  "missing argument after -n" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n

run_test_with_expected_exit \
  "unknown short option" \
  1 \
  "$APP" \
  -x

run_test_with_expected_exit \
  "unknown long option" \
  1 \
  "$APP" \
  --foobar

run_test_with_expected_exit \
  "wrong file type" \
  3 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -f xml

run_test_with_expected_exit \
  "invalid threshold letters" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -t abc

run_test_with_expected_exit \
  "invalid threshold negative" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -t -1

run_test_with_expected_exit \
  "invalid threshold decimal" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -t 10.5

run_test_with_expected_exit \
  "invalid top letters" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n abc

run_test_with_expected_exit \
  "invalid top negative" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n -1

run_test_with_expected_exit \
  "invalid top decimal" \
  1 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n 2.5

###############################################################################
# LOCAL / FILE ERRORS
###############################################################################

section "LOCAL / FILE ERRORS"

run_test_with_expected_exit \
  "missing input file" \
  2 \
  "$APP" \
  -i "$TMP_DIR/does_not_exist.log"

INPUT_DIR="$TMP_DIR/input_directory"
mkdir -p "$INPUT_DIR"

run_test_with_expected_exit \
  "input is a directory" \
  2 \
  "$APP" \
  -i "$INPUT_DIR"

EMPTY_FILE="$TMP_DIR/empty.log"
: >"$EMPTY_FILE"

run_test_with_expected_exit \
  "empty text file" \
  4 \
  "$APP" \
  -i "$EMPTY_FILE"

EMPTY_JSONL="$TMP_DIR/empty.jsonl"
: >"$EMPTY_JSONL"

run_test_with_expected_exit \
  "empty JSONL file" \
  4 \
  "$APP" \
  -i "$EMPTY_JSONL" \
  -f json

###############################################################################
# LOCAL / INVALID JSON
###############################################################################

section "LOCAL / INVALID JSON"

BAD_JSON="$TMP_DIR/bad.jsonl"

cat >"$BAD_JSON" <<'EOF'
{"ts":"2024-01-01T10:00:00Z","status":200,"duration_ms":120,"path":"/"}
this is not json
{"ts":"2024-01-01T10:00:02Z","status":500,"duration_ms":800,"path":"/api"}
EOF

run_test_with_expected_exit \
  "invalid JSONL" \
  4 \
  "$APP" \
  -i "$BAD_JSON" \
  -f json

INVALID_SCHEMA="$TMP_DIR/invalid_schema.jsonl"

cat >"$INVALID_SCHEMA" <<'EOF'
{"foo":"bar"}
EOF

run_test_with_expected_exit \
  "JSONL with invalid schema" \
  4 \
  "$APP" \
  -i "$INVALID_SCHEMA" \
  -f json

###############################################################################
# LOCAL / TOP LIMIT
###############################################################################

section "LOCAL / TOP LIMIT"

run_test_with_expected_exit \
  "top greater than available lines" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.log" \
  -n 99999

run_test_with_expected_exit \
  "JSON top greater than available lines" \
  0 \
  "$APP" \
  -i "$DATA_DIR/access.jsonl" \
  -f json \
  -n 99999

run_shell_test \
  "JSON top does not exceed requested value" \
  "'$APP' -i '$DATA_DIR/access.jsonl' -f json -n 2 | jq -e '.top_endpoints | length <= 2'"

###############################################################################
# LOCAL / IDEMPOTENCE
###############################################################################

section "LOCAL / IDEMPOTENCE"

"$APP" \
  -i "$DATA_DIR/access.log" \
  >"$TMP_DIR/text_a.out" \
  2>"$TMP_DIR/text_a.err"

STATUS_A=$?

"$APP" \
  -i "$DATA_DIR/access.log" \
  >"$TMP_DIR/text_b.out" \
  2>"$TMP_DIR/text_b.err"

STATUS_B=$?

if [[ "$STATUS_A" -eq 0 && "$STATUS_B" -eq 0 ]]; then
  run_test \
    "same text input produces same output" \
    diff -u "$TMP_DIR/text_a.out" "$TMP_DIR/text_b.out"
else
  printf '  %-65s %s\n' \
    "same text input produces same output" \
    "$(red "FAIL")"

  log ""
  log "TEST: same text input produces same output"
  log "RESULT: FAIL"
  log "First exit: $STATUS_A"
  log "Second exit: $STATUS_B"

  FAIL=$((FAIL + 1))
fi

###############################################################################
# DOCKER
###############################################################################

section "DOCKER"

if ! command -v docker >/dev/null 2>&1; then

  skip_test \
    "Docker test suite" \
    "docker command unavailable"

else

  ###########################################################################
  # Docker build
  ###########################################################################

  run_test \
    "Docker build" \
    docker build \
    -t "$IMAGE" \
    "$PROJECT_DIR"

  ###########################################################################
  # Docker help
  ###########################################################################

  run_test_with_expected_exit \
    "Docker help" \
    0 \
    docker run \
    --rm \
    "$IMAGE" \
    --help

  ###########################################################################
  # Docker text
  ###########################################################################

  run_test_with_expected_exit \
    "Docker text file" \
    0 \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log

  run_test_with_expected_exit \
    "Docker text threshold" \
    0 \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log \
    -t 800

  run_test_with_expected_exit \
    "Docker text top" \
    0 \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log \
    -n 3

  run_test \
    "display complete Docker text output" \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log

  ###########################################################################
  # Docker JSON
  ###########################################################################

  run_test_with_expected_exit \
    "Docker JSON file" \
    0 \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.jsonl \
    -f json

  run_test \
    "display complete Docker JSON output" \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.jsonl \
    -f json

  run_shell_test \
    "Docker JSON is valid" \
    "docker run --rm -v '$DATA_DIR:/data:ro' '$IMAGE' -i /data/access.jsonl -f json | jq -e . >/dev/null"

  run_shell_test \
    "Docker JSON has top_endpoints" \
    "docker run --rm -v '$DATA_DIR:/data:ro' '$IMAGE' -i /data/access.jsonl -f json | jq -e '.top_endpoints' >/dev/null"

  ###########################################################################
  # Docker stdin
  ###########################################################################

  run_shell_test \
    "Docker text stdin with -i -" \
    "cat '$DATA_DIR/access.log' | docker run --rm -i '$IMAGE' -i - >/dev/null"

  run_shell_test \
    "Docker JSON stdin with -i -" \
    "cat '$DATA_DIR/access.jsonl' | docker run --rm -i '$IMAGE' -i - -f json | jq -e . >/dev/null"

  ###########################################################################
  # Docker bad arguments
  ###########################################################################

  run_test_with_expected_exit \
    "Docker missing input" \
    0 \
    docker run \
    --rm \
    "$IMAGE"

  run_test_with_expected_exit \
    "Docker missing file" \
    2 \
    docker run \
    --rm \
    "$IMAGE" \
    -i /does/not/exist

  run_test_with_expected_exit \
    "Docker unreadable file" \
    2 \
    docker run \
    --rm \
    "$IMAGE" \
    -i /dev/null \
    -f xml

  ###########################################################################
  # Docker top
  ###########################################################################

  run_test_with_expected_exit \
    "Docker top greater than available endpoints" \
    0 \
    docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log \
    -n 99999

  ###########################################################################
  # Docker read-only filesystem
  ###########################################################################

  run_test_with_expected_exit \
    "Docker --read-only" \
    0 \
    docker run \
    --rm \
    --read-only \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.log

  ###########################################################################
  # Docker non-root
  ###########################################################################

  run_shell_test \
    "Docker runs as non-root" \
    "test \"$(docker run --rm --entrypoint id "$IMAGE" -u)\" != '0'"

  run_shell_test \
    "Docker user is sentry" \
    "docker run --rm --entrypoint id "$IMAGE" -un | grep -qx sentry"

  ###########################################################################
  # Docker metadata
  ###########################################################################

  run_shell_test \
    "Docker configured user is sentry" \
    "test \"\$(docker image inspect '$IMAGE' --format '{{.Config.User}}')\" = 'sentry'"

  ###########################################################################
  # Docker image size
  ###########################################################################

  IMAGE_SIZE_BYTES="$(
    docker image inspect \
      "$IMAGE" \
      --format '{{.Size}}' \
      2>/dev/null || echo 0
  )"

  IMAGE_SIZE_MB="$(
    awk \
      -v size="$IMAGE_SIZE_BYTES" \
      'BEGIN { printf "%.2f", size / 1024 / 1024 }'
  )"

  log ""
  log "Docker image size: ${IMAGE_SIZE_MB} MB"

  printf '  %-65s ' "Docker image < 30 MB"

  if awk \
    -v size="$IMAGE_SIZE_BYTES" \
    'BEGIN { exit !(size < 30 * 1024 * 1024) }'; then
    printf '%s\n' "$(green "PASS")"
    log "RESULT: PASS"
    PASS=$((PASS + 1))
  else
    printf '%s\n' "$(red "FAIL")"
    log "RESULT: FAIL"
    FAIL=$((FAIL + 1))
  fi

  ###########################################################################
  # Docker healthcheck
  ###########################################################################

  run_shell_test \
    "Docker healthcheck exists" \
    "test -n \"$(docker image inspect "$IMAGE" --format '{{json .Config.Healthcheck}}')\""

  ###########################################################################
  # Local vs Docker JSON
  ###########################################################################

  "$APP" \
    -i "$DATA_DIR/access.jsonl" \
    -f json \
    >"$TMP_DIR/local.json"

  LOCAL_STATUS=$?

  docker run \
    --rm \
    -v "$DATA_DIR:/data:ro" \
    "$IMAGE" \
    -i /data/access.jsonl \
    -f json \
    >"$TMP_DIR/docker.json"

  DOCKER_STATUS=$?

  if [[ "$LOCAL_STATUS" -eq 0 && "$DOCKER_STATUS" -eq 0 ]]; then

    run_test \
      "Docker JSON equals local JSON" \
      diff -u \
      <(jq -S 'del(.file)' "$TMP_DIR/local.json") \
      <(jq -S 'del(.file)' "$TMP_DIR/docker.json")

  else

    printf '  %-65s %s\n' \
      "Docker JSON equals local JSON" \
      "$(red "FAIL")"

    log ""
    log "TEST: Docker JSON equals local JSON"
    log "RESULT: FAIL"
    log "Local exit: $LOCAL_STATUS"
    log "Docker exit: $DOCKER_STATUS"

    FAIL=$((FAIL + 1))
  fi

  ###########################################################################
  # Docker signals
  ###########################################################################

  section "DOCKER / SIGNALS"

  CONTAINER_NAME="logsentry-signal-test-$$"
  FIFO="$TMP_DIR/logsentry-signal-$$.fifo"

  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -f "$FIFO"
  mkfifo "$FIFO"

  # Keep FIFO open for writing so stdin remains open for the container
  exec 9<>"$FIFO"

  # Run container in background reading from FIFO
  docker run \
    -i \
    --name "$CONTAINER_NAME" \
    "$IMAGE" \
    -i - \
    <"$FIFO" \
    >/dev/null 2>&1 &

  DOCKER_PID=$!

  # Wait briefly to ensure the container is up and running
  sleep 1

  # Verify if container started properly
  if [[ "$(docker inspect "$CONTAINER_NAME" --format '{{.State.Running}}' 2>/dev/null)" == "true" ]]; then

    START_TIME="$(date +%s)"

    # Send SIGTERM via docker stop (timeout of 2 seconds before SIGKILL)
    docker stop -t 2 "$CONTAINER_NAME" >>"$LOG_FILE" 2>&1
    STOP_STATUS=$?

    END_TIME="$(date +%s)"
    STOP_DURATION=$((END_TIME - START_TIME))

    EXIT_CODE="$(docker inspect "$CONTAINER_NAME" --format '{{.State.ExitCode}}' 2>/dev/null)"

    log "docker stop exit status: $STOP_STATUS"
    log "container exit code: $EXIT_CODE"
    log "stop duration: ${STOP_DURATION}s"

    printf '  %-65s ' "Docker SIGTERM / graceful stop"

    # Exit code 143 = 128 + 15 (SIGTERM)
    if [[ "$STOP_STATUS" -eq 0 && "$EXIT_CODE" == "143" && "$STOP_DURATION" -lt 2 ]]; then
      printf '%s\n' "$(green "PASS")"
      log "RESULT: PASS"
      PASS=$((PASS + 1))
    else
      printf '%s\n' "$(red "FAIL")"
      log "RESULT: FAIL"
      log "Reason: expected exit 143 and stop duration < 2s (got exit=$EXIT_CODE, duration=${STOP_DURATION}s)"
      FAIL=$((FAIL + 1))
    fi

  else
    printf '  %-65s ' "Docker SIGTERM / graceful stop"
    printf '%s\n' "$(yellow "SKIP")"
    log "RESULT: SKIP"
    log "Reason: container was not running after startup"
    SKIP=$((SKIP + 1))
  fi

  # Close FIFO descriptor and clean up background background process
  exec 9>&-
  kill "$DOCKER_PID" >/dev/null 2>&1 || true
  wait "$DOCKER_PID" >/dev/null 2>&1 || true
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -f "$FIFO"
fi

###############################################################################
# SUMMARY
###############################################################################

section "SUMMARY"

TOTAL=$((PASS + FAIL + SKIP))

log ""
log "Finished: $(date)"
log "Total: $TOTAL"
log "PASS: $PASS"
log "FAIL: $FAIL"
log "SKIP: $SKIP"

printf '\n'
printf '%s\n' "$(blue "==================== RESULT ====================")"
printf 'Total : %d\n' "$TOTAL"
printf 'Passed: %s\n' "$(green "$PASS")"
printf 'Failed: %s\n' "$(red "$FAIL")"
printf 'Skipped: %s\n' "$(yellow "$SKIP")"
printf 'Log   : %s\n' "$LOG_FILE"
printf '%s\n' "$(blue "=================================================")"
printf '\n'

if [[ "$FAIL" -eq 0 ]]; then
  printf '%s\n' "$(green "All mandatory tests passed.")"
  exit 0
fi

printf '%s\n' "$(red "Some tests failed. See the log file for details.")"
cleanup
exit 1
