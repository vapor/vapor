# HTTP performance harness

Compare the current Vapor checkout, Vapor 4 and Hummingbird with matching HTTP/1.1
workloads. The separate packages do not affect normal library builds. They use
released dependencies and run without any optimization patches or SwiftPM edits.

Requires Swift 6.4, Python 3 and `wrk` (`brew install wrk` on macOS). macOS builds
require 26.2 or later; Linux is supported by the package manifests and CI builds.

```sh
python3 Performance/compare.py
python3 Performance/compare.py status tiny json large stream --duration 30 --connections 256
python3 Performance/compare.py status tiny json large stream --frameworks vapor http-server vapor4 hummingbird
python3 Performance/compare.py tiny --frameworks vapor vapor-direct vapor-no-middleware http-server
```

Vapor 4.122.1 and Hummingbird 2.26.0 are pinned in `Comparisons/Package.swift`.
SwiftNIO and swift-log comparison pins match the prepared current-Vapor locks.
Revisit these pins together when refreshing dependencies, and retain the resolved
revisions with results. Never silently compare runs across dependency updates.

## Workloads

| Route under `/bench/` | Response | Purpose |
| --- | --- | --- |
| `status` | 204, no body | Minimum response overhead |
| `tiny` | 2 B text | Small response overhead |
| `small` | 1 KiB text | Typical buffered response |
| `json` | JSON object with id, name and tags | Per-request content encoding |
| `large` | 64 KiB text | Buffered copying and transport |
| `stream` | Sixteen awaited 1 KiB writes | Streaming and flushing |
| `file` | 1 MiB, 128 KiB read chunks | File-response API with a warmed file cache |

All three frameworks support these workloads. The raw `http-server` supports every
shape except `file`; `vapor-direct` supports `status`, `tiny`, `small`, `json` and
`large`. `vapor-no-middleware` retains the router but removes default middleware.
JSON is compared semantically, and all other responses are checked byte-for-byte
before load. Streaming has a known content length. File helpers perform different
HTTP metadata/range work, so file results are an API-level comparison, not a disk or
identical-operation benchmark.

Additional Vapor routing diagnostics exercise parameter lengths, catchalls,
encoded literals, partial alternatives, partial captures and backtracking:

```sh
python3 Performance/compare.py routing-parameter/42 routing-catchall/a/b/c \
  routing-shadowed/f%69xed/end routing-alternatives/f%69xed.txt/end \
  routing-partial/report.txt routing-backtrack/fixed/end --frameworks vapor
```

These diagnostic routes have no matched Hummingbird/Vapor 4 fixture; the harness
rejects unsupported combinations. Use `--help` for the complete route selection.
Request-ID access, POST echo/body draining, isolated trie lookup and component
allocation/instruction measurements are covered in [Benchmarks](../Benchmarks/README.md).

## Repeating and saving comparisons

The driver builds before measuring, validates complete responses, discards warmups
and rotates framework order. Defaults are three passes, 10 seconds measured,
3 seconds warmup, 64 connections, four wrk threads and four server event-loop/blocking
threads. Servers run one at a time on loopback with POSIX sockets, plaintext HTTP/1.1,
keep-alive, no pipelining/compression and request logging disabled.

```sh
python3 Performance/compare.py tiny json --interleave-routes --record-cpu \
  --server-threads 4 --connections 16 --output /tmp/vapor-comparison
# Compare a saved baseline executable with the newly built candidate:
python3 Performance/compare.py tiny --frameworks vapor-baseline vapor --skip-build \
  --binary vapor-baseline=/absolute/path/to/saved/PerformanceServer
# Save all three counter suites plus the five primary HTTP shapes:
python3 Performance/run-iteration.py main-baseline
```

`--interleave-routes` restarts each server per route to bring comparable samples
closer together. `--record-cpu` adds diagnostic process CPU per completed request,
including measured connection setup/teardown but excluding warmup. `--wrk PATH`
selects and hashes a specific load generator. The earlier `run-wrk.sh` remains a
convenience runner; use the Python harness for reproducible comparisons.

Each new `Results/<name-or-UTC-time>/` directory stores:

- Raw warmup/load output and server/build logs, including failed attempts.
- Every measured sample in `results.json`, with response headers, validation and command.
- Median throughput/range and median per-run latency percentiles in `summary.md`.
- Compiler, hardware, settings, Git revision/status, source/binary/client hashes and dependency locks.
- Server shutdown status, including forced termination.

The counter runner also saves raw baselines, JMH exports, counter availability, interposer hashes,
SwiftPM workspace selections and the current source diff. Results are ignored by
Git; archive them with your report. `--skip-build` explicitly trusts existing
executables: keep the source revision, patches and lockfiles with saved binaries;
checkout metadata alone does not describe their source.

Socket errors, timeouts, HTTP errors, empty/invalid measurements and incorrect
responses abort the run. Completed samples and raw logs remain available. Only
children started by this driver are stopped, including after failure/interruption.

## Reproducing dependency versions

From a clean checkout, before building:

```sh
cp Performance/DependencyLocks/benchmarks.json Benchmarks/Package.resolved
cp Performance/DependencyLocks/performance.json Performance/Package.resolved
cp Performance/DependencyLocks/comparisons.json Performance/Comparisons/Package.resolved
swift package --package-path Benchmarks resolve
swift package --package-path Performance resolve
swift package --package-path Performance/Comparisons resolve
```

Use a fresh build directory to avoid carrying SwiftPM edited dependencies between
branches. Package.resolved files are machine-local; the named snapshots are tracked.
Each run records its actual resolutions; the counter runner also records workspace
selections. Lockfiles alone do not describe edited dependencies. Linux may add
platform-specific interposer pins; keep that platform's actual lock with its results.

## Validation and limits

```sh
python3 -m unittest discover -s Performance/Tests
swift build --package-path Performance -c release
swift build --package-path Performance/Comparisons -c release
```

CI also runs the counter fixture smoke mode described in `Benchmarks/README.md`.
The benchmark branch provides measurement infrastructure, not performance changes
or a claim that one framework is universally faster.

Client/server CPU contention, background work, thermal state and power settings
matter on loopback. Repeat on quiet machines with balanced samples; use a separate
load generator for stronger server-capacity claims. wrk is a closed-loop saturation
test, not fixed-arrival-rate latency. Reported p99 is the median of individual run
p99s, not the percentile of a merged distribution. Missing hardware counters must
be reported as unavailable. Do not compare numbers across hosts/toolchains as an
optimization effect.
