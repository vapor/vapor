# Initial comparison — 16 September 2026

Follow-up: the [17 September investigation](INVESTIGATION.md) identifies and measures a
buffered-write bottleneck in the underlying HTTP server. The results below remain the
original baseline, before that experimental patch.

Current Vapor is faster than Vapor 4 in these streaming and cached-file workloads, and
slower in these buffered-response and JSON workloads. Hummingbird leads the tiny, small,
and JSON cases; current Vapor and Hummingbird are close on streaming and cached files.
These are observations from this local run, not general framework rankings.

## Median throughput

Requests per second; higher is better. Three measured samples per cell.

| Workload | Current Vapor | Vapor 4.122.1 | Hummingbird 2.26.0 | Current vs Vapor 4 |
| --- | ---: | ---: | ---: | ---: |
| Tiny, 2 B | 58,853 | 74,991 | 84,498 | −21.5% |
| Small, 1 KiB | 61,484 | 73,098 | 83,304 | −15.9% |
| Large, 64 KiB | 35,986 | 45,892 | 41,493 | −21.6% |
| JSON, 48 B | 61,899 | 69,193 | 84,126 | −10.5% |
| Stream, 16 × 1 KiB | 13,717 | 10,215 | 14,042 | +34.3% |
| Cached file, 1 MiB | 4,243 | 2,787 | 4,256 | +52.2% |

## Tail latency

Median of the three per-run p99 values, in milliseconds; lower is better. This is not a
pooled p99, and the load generator is closed-loop. The [full summary](Results/2026-09-16-macos-c64-repeat/summary.md)
also includes p50 and throughput min–max ranges.

| Workload | Current Vapor | Vapor 4.122.1 | Hummingbird 2.26.0 |
| --- | ---: | ---: | ---: |
| Tiny | 4.256 | 2.551 | 1.105 |
| Small | 3.933 | 2.186 | 1.165 |
| Large | 2.799 | 2.312 | 9.827 |
| JSON | 2.843 | 1.947 | 1.559 |
| Stream | 6.763 | 8.535 | 5.763 |
| Cached file | 20.866 | 42.321 | 25.406 |

## Setup and validation

- Apple M1 Pro, 10 cores, 32 GiB RAM; macOS 27.0; Apple Swift 6.4 (`swiftlang-6.4.0.34.1`); `wrk` 4.2.0.
- Current Vapor: `5dfe8b81197d9edfe0298a3961ee119c11e413fd`, with the performance-app changes in this working tree. No framework implementation changes.
- All three executables built in release mode. SwiftNIO 2.101.3 and swift-log 1.15.0 matched across frameworks. Other resolved dependencies are archived below.
- Plaintext HTTP/1.1 over loopback; keep-alive; no pipelining; 64 connections; four `wrk` threads. Four NIO event-loop threads and four singleton blocking-pool threads per server, using POSIX transport. This does not limit the Swift concurrency executor to four cores.
- Each measurement lasted five seconds after a discarded three-second warm-up. Framework order rotated on each pass: current/4/Hummingbird, 4/Hummingbird/current, Hummingbird/current/4.
- One server ran at a time, and all builds finished before measurement. Request-log output was suppressed. Framework middleware and response-header behavior were otherwise left as configured in the adapters.
- Complete response bodies were validated before each warm-up (JSON by decoded value and content type). All payload sizes matched across frameworks.
- The completed comparison contains **54 measurements and 12,436,139 measured requests**, with **zero reported connect/read/write/status errors or timeouts**, including its warm-ups.

The current server uses `Application.start()` for signal handling and lifecycle cleanup.
The adapters, driver, and logging changes are confined to `Performance/`.

## Limitations and failed attempt

This was a working laptop with background activity, including Time Machine. The client and
server competed for the same hardware. Throughput ranges and tail latencies expose some of
that variability: Hummingbird's 64 KiB case ranged from **33,483 to 45,752 req/s**, and its
per-run p99 ranged from **1.698 to 78.656 ms**. Close results do not establish a winner.

The first attempt stopped on **one timeout in current Vapor's 64 KiB warm-up**. Its output
is [retained separately](Results/2026-09-16-macos-c64/README.md) and excluded from the tables.
The cause was not established; the completed repeat does not erase that observation.

The file tests exercise different APIs: both Vapor versions perform HTTP file-response
metadata work, including ETag/range handling, while Hummingbird uses `FileIO.loadFile`.
All use the same cached 1 MiB fixture and 128 KiB chunks, but this is an API-level comparison,
not equal-work disk I/O. Headers also differ on other routes: for example, Vapor 4 and
Hummingbird include `Date` in the validated responses, while this current-Vapor app does not.
The response headers are recorded in every measured sample.

## Reproduce and inspect

From `Performance/`:

```sh
python3 compare.py --duration 5 --warmup 3 --repeats 3
```

The actual measurement command used `--skip-build` after all release builds succeeded,
and `--output Performance/Results/2026-09-16-macos-c64-repeat` from the repository root.
Fresh runs use a new output directory. To reproduce the dependency graph, restore the saved
lock files before building:

```sh
# From Performance/
cp Results/2026-09-16-macos-c64-repeat/dependencies-vapor.json Package.resolved
cp Results/2026-09-16-macos-c64-repeat/dependencies-vapor4.json Comparisons/Package.resolved
```

This assumes the same package manifests and current-Vapor source revision. SwiftPM may
resolve again if the manifests change; always compare the archived dependency versions.

- [Every measured sample and response headers](Results/2026-09-16-macos-c64-repeat/results.json)
- [Machine, compiler, settings, source and binary hashes](Results/2026-09-16-macos-c64-repeat/metadata.json)
- [Current Vapor dependencies](Results/2026-09-16-macos-c64-repeat/dependencies-vapor.json)
- [Vapor 4 / Hummingbird dependencies](Results/2026-09-16-macos-c64-repeat/dependencies-vapor4.json)
- [Current Vapor build log](Results/2026-09-16-macos-c64-repeat/build-vapor.log)
- [Comparison servers build log](Results/2026-09-16-macos-c64-repeat/build-comparisons.log)

Individual warm-up, measurement, and server logs are alongside these files.

## Next measurements

Repeat with longer samples on a quiet, dedicated Linux server and a separate load generator,
then sweep concurrency rather than treating 64 connections as a universal operating point.
Add matched POST-body echo/JSON decode and parameterized-route workloads. Hummingbird's
existing [performance server](https://github.com/hummingbird-project/hummingbird/blob/2.26.0/Sources/PerformanceTest/main.swift)
and [router/HTTP microbenchmarks](https://github.com/hummingbird-project/hummingbird/tree/2.26.0/Benchmarks/HummingbirdBenchmarks)
provide useful starting points. The microbenchmark suite was inspected, not run in this comparison.
