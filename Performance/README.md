# Performance

A standalone Vapor app plus a `wrk` driver, for load-testing the request/response path on demand.
Separate package, so it never affects the main build.

## Compare Vapor, Vapor 4, and Hummingbird

See the [initial measured results](RESULTS.md) for the 16 September 2026 laptop baseline,
including throughput, tail latency, raw data, and limitations.

```sh
cd Performance
python3 compare.py                         # build all three; all six routes
python3 compare.py tiny json               # selected routes
python3 compare.py --duration 30 --connections 256
python3 compare.py --skip-build            # reuse release binaries after building
python3 compare.py tiny --frameworks vapor # just the current checkout
```

Requires Swift 6.4, Python 3, and `wrk` (`brew install wrk`). The current package targets
macOS 26.2 or later. Comparison servers live in the independent `Comparisons/` package:
Vapor **4.122.1** and Hummingbird **2.26.0**, pinned to exact releases. Its SwiftNIO **2.101.3**
and swift-log **1.15.0** pins match the initial current-Vapor baseline; revisit these pins
when updating that baseline. All dependency revisions are saved with each run.

The driver builds everything before measuring, checks every response's complete body
(JSON semantically), runs discarded warm-ups, and rotates framework order between passes.
Defaults: three passes, 10 seconds per measurement, 3 seconds warm-up, 64 connections,
four `wrk` threads, and four NIO event-loop and blocking-pool threads. All servers use
the POSIX socket transport, including Hummingbird on macOS. Each server runs alone on
loopback port 18080, using plaintext HTTP/1.1 with keep-alive and no pipelining or compression.
Request-log output is disabled; each framework otherwise retains its configured/default
middleware (the Hummingbird router has no added middleware).

Results go to a new `Results/<UTC timestamp>/` directory (override with `--output`):

- `summary.md`: median throughput, min–max throughput, and median per-run p50/p99 latency.
- `results.json`: every measured sample, response headers, body sizes, and load commands.
- `metadata.json`: hardware, compiler, settings, current Vapor revision, source and binary hashes.
- `dependencies-*.json`: resolved dependency versions and revisions.
- `*-warmup.txt`, `*-measured.txt`, and server/build logs: raw output.

Any socket error, timeout, HTTP error counted by `wrk`, empty measurement, or failed response
validation aborts the run. Completed samples and raw logs are retained on failure. The driver
stops its servers on completion, failure, or interruption. Use `--help` for all settings.
`--skip-build` trusts the existing binaries; rebuild after changing sources or dependencies.

The buffered and JSON routes use each framework's normal response conversion/encoding.
The streaming route performs sixteen awaited 1 KiB writes with a known content length.
The file route uses a shared 1 MiB fixture and 128 KiB read chunks, warmed into the OS cache.
Vapor uses its HTTP file-response helper (including file metadata/ETag/range handling);
Hummingbird uses `FileIO.loadFile`. Treat this as an API-level file-serving comparison:
the helpers perform different amounts of HTTP work. Response headers are recorded so those
differences remain visible. This is not a disk-throughput test.

## Isolate the HTTP server

See the [17 September investigation](INVESTIGATION.md) for layer isolation, CPU profiling,
and the measured effect of batching buffered response writes.

```sh
python3 compare.py tiny large --frameworks vapor vapor-direct vapor-no-middleware http-server
```

`http-server` calls `NIOHTTPServer` directly, without Vapor. It supports `tiny`, `small`,
`large`, `json`, and `stream`; JSON is encoded per request. It consumes request end so
connections remain reusable. It has no file-serving workload. `vapor-direct` bypasses
Vapor's router and middleware using a custom responder and supports the four buffered
routes. `vapor-no-middleware` retains routing but removes middleware. Normal `vapor`
measurements and the default three-framework selection are unchanged.

Use `--skip-build --binary FRAMEWORK=/absolute/path/to/executable` to compare saved release
executables without rebuilding during measurement. Overrides are hashed in the metadata.
The explicit `vapor-batched` and `http-server-batched` labels require saved binary overrides
and are for the [HTTP-server batching experiment](Patches/README.md). Dependency lock files
alone cannot describe a patched executable: keep its patch and build provenance with the results.

## Existing Hummingbird benchmarks

Hummingbird includes a [`PerformanceTest` server](https://github.com/hummingbird-project/hummingbird/blob/2.26.0/Sources/PerformanceTest/main.swift)
with plaintext, JSON, POST-body echo, and delayed responses, plus example `wrk` commands.
The adapters here follow the same approach but match Vapor's existing payloads and suppress
request-log output. The upstream server enables debug request logging, so running it unchanged
would introduce a logging difference.

Its [`HummingbirdBenchmarks` suite](https://github.com/hummingbird-project/hummingbird/tree/2.26.0/Benchmarks/HummingbirdBenchmarks)
uses `package-benchmark` for routers, URI/query parsing, cookies, and URL-encoded forms:

```sh
# In a Hummingbird checkout; requires package-benchmark's platform dependencies.
ENABLE_HB_BENCHMARKS=1 swift package benchmark
```

These are useful candidates for future matched microbenchmarks, but are not equivalent to
end-to-end HTTP throughput. This comparison driver does not run that microbenchmark suite.

## Original single-server runner

```sh
cd Performance
./run-wrk.sh                       # every route
./run-wrk.sh tiny large            # selected routes
DURATION=30s CONNECTIONS=256 ./run-wrk.sh
```

Requires `wrk` (`brew install wrk`). The script builds the server, starts it, waits until it is
actually serving, runs a discarded warm-up before each measurement, and shuts it down afterwards.
Use `compare.py` for repeated measurements, complete response validation, and saved error counts.

## Routes

| route | body | what it tells you |
| --- | --- | --- |
| `/bench/tiny` | 2 B | throughput ceiling - overhead only, payload is irrelevant |
| `/bench/small` | 1 KiB | typical small buffered response |
| `/bench/large` | 64 KiB | buffered response where copying dominates |
| `/bench/json` | 48 B | `Content` encoding |
| `/bench/stream` | 16 KiB | streaming writer, 16 awaited chunks |
| `/bench/file` | 1 MiB | real `FileIO` streaming, 8 x 128 KiB chunks |

## Interpreting the numbers

The client and server share one machine, so CPU contention, background applications, power mode,
and thermal state affect the results. Small differences or overlapping ranges need longer runs
on a quiet machine. `wrk` is a closed-loop saturation test; its percentiles do not establish
latency at a fixed arrival rate. The summary's latency columns are medians of individual runs'
percentiles, not percentiles of a combined latency distribution.

Use these measurements as a local starting point, not a production capacity claim or a universal
framework ranking. For stronger conclusions, repeat on a dedicated Linux server with a separate
load generator, sweep connection counts, and add matched microbenchmarks to attribute differences.
This checkout currently has no tracked runnable sources in `Benchmarks/`.
