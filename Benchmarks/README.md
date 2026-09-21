# Allocation and instruction benchmarks

Requires Swift 6.4 and macOS 26.2 or later, or Linux. This standalone package
benchmarks the current Vapor checkout. The in-memory suite uses
`@_spi(Benchmarking) import Vapor` and
`Application.makeBenchmarkResponder()` to access the configured responder from
this separate package. Normal imports do not expose the hook; VaporTesting keeps
using the existing package-access `makeResponder()`. No testing-enabled build of
Vapor or benchmark dependencies in Vapor's root manifest are required.

```sh
swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark list
NIO_SINGLETON_GROUP_LOOP_COUNT=4 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=4 \
  swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark \
  --filter '^(e2e|network|drain-network)/.*' --no-progress --scale

# Run all fixtures, including component benchmarks:
NIO_SINGLETON_GROUP_LOOP_COUNT=4 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=4 \
  swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark \
  --no-progress --scale
```

The package contains one executable target, `VaporBenchmarks`. Use `--filter` to
select fixtures by name. Socket benchmarks require `--disable-sandbox` so the
benchmark plugin can start a loopback server.

## Coverage and measurement boundaries

| Suite | Coverage | Includes |
| --- | --- | --- |
| Vapor `e2e/` | 204 empty, 2 B/1 KiB/64 KiB text, JSON, and four streamed response shapes below | Request construction, routing, default middleware, encoding and complete body consumption into a copying sink |
| Vapor `network/` | The same nine response shapes plus four streamed upload cases | Real plaintext HTTP/1.1 server, persistent loopback connection, AsyncHTTPClient and complete body collection |
| Vapor `network/` extras | Request ID accessed once/ten times; 1 KiB/64 KiB POST echo | Real request adapter and upload collection |
| Vapor `drain-network/` | Unread 1 KiB/64 KiB uploads | Response followed by bounded body draining and keep-alive reuse |
| `trie/` | Literals, plain/long/escaped parameters, three captures, selected/bypassed/nested catchalls, partial matches/misses/alternatives, backtracking, case folding, static misses, anonymous wildcards and 200/1,000-route tables | One lookup and fresh capture storage; router, path and logger construction excluded |
| `routing/` | Shallow/deep/200-route lookup, 200/1,000-route responder construction, literal/parameter neighbours, escaping, trailing slash, HEAD precedence, case folding, misses, methods, typed captures | Vapor responder and copying body sink, except explicit construction/parameter-access cases |
| `request/` | Request and URI construction/mutation, origin paths, request-ID reads | The named component operation |
| Remaining suites | Content/query decoding, array-valued form encoding/decoding, cookie parsing, authentication, middleware depth, response construction/serialization, writer overloads, chunk sizes and macro routes | The named component operation; see each fixture |

### Request and response streaming

| Fixture | Operation |
| --- | --- |
| `e2e/stream`, `network/stream` | Sixteen awaited 1 KiB writes, known 16 KiB length |
| `e2e/stream-chunked`, `network/stream-chunked` | Same writes with unknown length; the network fixture validates chunked HTTP/1.1 framing |
| `e2e/stream-coarse`, `network/stream-coarse` | One 64 KiB write, known length |
| `e2e/stream-fine`, `network/stream-fine` | 256 awaited 256 B writes, same 64 KiB total and known length |
| `network/collect-upload-known`, `network/collect-upload-chunked` | Client yields sixteen 4 KiB chunks; server collects the upload and returns a buffered echo |
| `network/stream-upload-known`, `network/stream-upload-chunked` | Same upload forwarded as it is read, without whole-body collection; response has unknown length |

Upload suffixes select `Content-Length` or chunked request framing. Every measured
request gets a fresh client body stream. Transport may coalesce chunks, so the
client's yield count does not prescribe server read boundaries. The responder-only
`e2e/` cases cannot measure HTTP framing; request-stream coverage uses real sockets.
The existing `stream/` and `writer/` suites remain useful for isolating body/writer
cost from the socket and client costs.

Network startup, shutdown and complete response validation happen outside timing.
The normal measured loop includes client request construction, status validation and
body collection. JSON is encoded per request. Both `e2e/` and the response/upload `network/`
fixtures validate complete bodies before timing; network stream fixtures also check
response framing. Keep fixture code and measurement boundaries fixed when
comparing saved baselines.

**Network instruction/allocation totals include both client and server.** They are
not server-only counts or saturation throughput measurements.

Metrics are instructions, malloc count and wall-clock time. On macOS instructions
use `proc_pid_rusage`; Linux requires accessible perf counters. A missing/zero
instruction counter means unavailable, not an improvement. Keep the benchmark
package's default interposer traits enabled for allocation counts, and keep
interposer and compiler versions fixed between comparisons.

## Fast validation and CI

```sh
BENCHMARK_SMOKE=1 NIO_SINGLETON_GROUP_LOOP_COUNT=2 NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT=2 \
  swift package --package-path Benchmarks --disable-sandbox --allow-writing-to-package-directory benchmark --no-progress
```

This executes every fixture once with wall-clock measurement only, no warmup and no
scaled repetitions. It exercises setup, request handling, validation and teardown
without requiring hardware counters. **Smoke results are not performance results.**
CI builds the release target and executes this mode; performance thresholds belong
on a controlled benchmark machine, not shared CI hosts.

See [coverage and remaining scenarios](COVERAGE.md) for the measurement boundaries
and future additions. Keep the compiler version, Git revision, local changes,
`Benchmarks/Package.resolved`, machine configuration and raw output with saved
results. Use the same dependency revisions when comparing runs.
