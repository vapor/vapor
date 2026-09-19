# Allocation and instruction benchmarks

Requires Swift 6.4. These independent packages benchmark the current Vapor checkout
and released dependencies; no HTTP Server, RoutingKit or Vapor optimization patch
is required. `Application.makeResponder()` exposes the configured responder so the
in-memory suite can measure it from this separate package.

```sh
swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark list
NIO_SINGLETON_GROUP_LOOP_COUNT=4 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=4 \
  swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark \
  --filter '^(e2e|network)/.*' --no-progress --scale

# Save counters, dependency revisions, hashes and HTTP results together:
python3 Performance/run-iteration.py main-baseline
# All Vapor component counters, without running wrk:
python3 Performance/run-iteration.py components --targets VaporBenchmarks --counters-only --filter '.*'
```

Use `--target VaporBenchmarks`, `--target RawHTTPServerBenchmarks`, or
`--target HummingbirdBenchmarks` with the Swift plugin to select a suite.
The Python runner uses `--targets` (plural) and defaults to all three suites.

## Coverage and measurement boundaries

| Suite | Coverage | Includes |
| --- | --- | --- |
| Vapor `e2e/` | 204 empty, 2 B text, JSON, 64 KiB text, sixteen 1 KiB streamed chunks | Request construction, routing, default middleware, encoding and complete body consumption into a copying sink |
| All three `network/` suites | The same five response shapes | Real plaintext HTTP/1.1 server, persistent loopback connection, AsyncHTTPClient and complete body collection |
| Vapor `network/` extras | Request ID accessed once/ten times; 1 KiB/64 KiB POST echo | Real request adapter and upload collection |
| Vapor `drain-network/` | Unread 1 KiB/64 KiB uploads | Response followed by bounded body draining and keep-alive reuse |
| `trie/` | Literals, plain/long/escaped parameters, three captures, selected/bypassed/nested catchalls, partial matches/misses/alternatives, backtracking, case folding, static misses, anonymous wildcards and 200/1,000-route tables | One lookup and fresh capture storage; router, path and logger construction excluded |
| `routing/` | Shallow/deep/200-route lookup, 200/1,000-route responder construction, literal/parameter neighbours, escaping, trailing slash, HEAD precedence, case folding, misses, methods, typed captures | Vapor responder and copying body sink, except explicit construction/parameter-access cases |
| `request/` | Request and URI construction/mutation, origin paths, request-ID reads | The named component operation |
| Remaining suites | Content/query decoding, authentication, middleware depth, response construction/serialization, writer overloads, chunk sizes and macro routes | The named component operation; see each fixture |

Network startup, shutdown and complete response validation happen outside timing.
The normal measured loop includes status validation and body collection. All three
network suites use the same payloads, client, collection limit and scaling. JSON is
encoded per request; streaming performs sixteen awaited writes with a known length.

**Network instruction/allocation totals include both client and server.** They are
not server-only counts or saturation throughput measurements. The raw-server suite
removes Vapor's adapter/router/middleware but still includes its own response work.
Use [the separate HTTP harness](../Performance/README.md) for throughput and latency.
Vapor's in-memory copying sink differs from Hummingbird's upstream no-op sink; do not
compare those upstream microbenchmark numbers as though their scopes were equal.

Metrics are instructions, malloc count and wall-clock time. The runner additionally
exports throughput. On macOS instructions use `proc_pid_rusage`; Linux requires
accessible perf counters. A missing/zero instruction counter means unavailable, not
an improvement. Keep the benchmark package's default interposer traits enabled for
allocation counts; the runner sets `LD_PRELOAD` for its Linux interposers. Keep
interposer and compiler versions fixed between comparisons.

## Fast validation and CI

```sh
BENCHMARK_SMOKE=1 NIO_SINGLETON_GROUP_LOOP_COUNT=2 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=2 \
  swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark --no-progress
```

This executes every fixture once with wall-clock measurement only, no warmup and no
scaled repetitions. It exercises setup, request handling, validation and teardown
without requiring hardware counters. **Smoke results are not performance results.**
CI builds all release targets and executes this mode; performance thresholds belong
on a controlled benchmark machine, not shared CI hosts.

For repeatable dependencies, restore the snapshots in `Performance/DependencyLocks/`
using the commands in the HTTP harness README. Keep each run's exported locks,
metadata and raw results when comparing machines.
