#!/bin/zsh
# Load-test Vapor's request/response path with `wrk`.
#
#   ./run-wrk.sh                      # all routes, default settings
#   ./run-wrk.sh tiny large           # only these routes
#   DURATION=30s CONNECTIONS=256 ./run-wrk.sh
#
# Builds and starts the server itself, waits until it actually serves, runs a discarded warm-up
# before each measured run, then shuts the server down.
#
# Numbers from `wrk` move a great deal with whatever else the machine is doing - a build running in
# the background roughly halved throughput when this was written. Close everything else, and treat
# small differences between runs as noise rather than signal. For attributable numbers (allocations
# and instructions) use the package-benchmark suite in ../Benchmarks instead.
set -e
cd "${0:A:h}"

PORT="${PERF_PORT:-8080}"
THREADS="${THREADS:-4}"
CONNECTIONS="${CONNECTIONS:-64}"
DURATION="${DURATION:-10s}"
ROUTES=(${@:-tiny small large json stream file})

command -v wrk >/dev/null || { echo "wrk not found - brew install wrk"; exit 1; }

echo "building..."
swift build -c release --product PerformanceServer

# Server output goes to a log rather than the terminal - Vapor logs every request, which would
# bury the results table under thousands of lines during a run.
SRVLOG="${TMPDIR:-/tmp}/vapor-perf-server.log"
PERF_PORT=$PORT ./.build/release/PerformanceServer > "$SRVLOG" 2>&1 &
SRVPID=$!
trap "kill $SRVPID 2>/dev/null" EXIT

for i in {1..30}; do
  curl -sf -o /dev/null --max-time 1 "http://127.0.0.1:$PORT/bench/tiny" && break
  sleep 1
done
curl -sf -o /dev/null "http://127.0.0.1:$PORT/bench/tiny" || {
  echo "server never came up on $PORT; last lines of $SRVLOG:"; tail -5 "$SRVLOG"; exit 1
}

printf "\n%-10s %12s %10s %10s %10s\n" route req/s p50 p99 bytes
for r in $ROUTES; do
  URL="http://127.0.0.1:$PORT/bench/$r"
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
  BYTES=$(curl -s -o /dev/null -w '%{size_download}' "$URL")
  if [[ "$CODE" != "200" ]]; then
    printf "%-10s %12s\n" "$r" "HTTP $CODE"
    continue
  fi
  wrk -t2 -c16 -d3s "$URL" >/dev/null 2>&1                     # warm-up, discarded
  RES=$(wrk -t"$THREADS" -c"$CONNECTIONS" -d"$DURATION" --latency "$URL" 2>&1)
  printf "%-10s %12s %10s %10s %10s\n" \
    "$r" \
    "$(echo "$RES" | awk '/Requests\/sec/{print $2}')" \
    "$(echo "$RES" | awk '/ 50%/{print $2}')" \
    "$(echo "$RES" | awk '/ 99%/{print $2}')" \
    "$BYTES"
done
