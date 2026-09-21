# Benchmark coverage review

Reviewed against Vapor main `7f838018d` and Hummingbird main
[`e027f279b5bdba98aa242efac6b47326a0857ca8`](https://github.com/hummingbird-project/hummingbird/tree/e027f279b5bdba98aa242efac6b47326a0857ca8)
on 2026-09-19. Comparison executables continue to use the pinned Hummingbird 2.26.0
dependency; inspecting upstream does not silently update measured dependencies.

## What each layer answers

| Layer | Useful question | Boundary |
| --- | --- | --- |
| `trie/`, request/content/auth/writer and other component fixtures | Which operation changed allocations or instructions? | Fixture-specific setup and consumption; no real network |
| Vapor `e2e/` | What does a complete responder invocation cost? | Fresh Vapor request, routing, default middleware, encoding, copying body sink; no HTTP codec or socket |
| Three matched `network/` targets | Did the real HTTP path change? | Client and server in one process, serial loopback requests and complete response consumption |
| `Performance/compare.py` | What throughput and latency does the HTTP stack deliver under concurrent load? | Separate wrk/server processes; HTTP/1.1 parsing, routing, middleware, handler, response writing and sockets |

The last two layers cover real request and response streaming. In-memory content
fixtures construct already-collected request bodies and cannot replace streamed
upload fixtures. Counter totals for `network/` include client allocations and work;
the external harness offers separate process CPU diagnostics.

## Findings from Hummingbird

Hummingbird's [responder benchmarks](https://github.com/hummingbird-project/hummingbird/blob/e027f279b5bdba98aa242efac6b47326a0857ca8/Benchmarks/HummingbirdBenchmarks/RouterBenchmarks.swift)
consume response bodies through a no-op writer. They include collected uploads,
streamed echo, routing, middleware and a metrics backend. They reuse request/context
state in some cases and execute 50 inner operations per iteration. Vapor's copying
sink and fresh requests have a different scope, so upstream figures are not direct
framework comparisons. Our matched network fixtures use the same client and bodies.

Their [HTTP fixtures](https://github.com/hummingbird-project/hummingbird/blob/e027f279b5bdba98aa242efac6b47326a0857ca8/Benchmarks/HummingbirdBenchmarks/HTTPBenchmarks.swift)
cover URI, query and cookie parsing. Their [form fixtures](https://github.com/hummingbird-project/hummingbird/blob/e027f279b5bdba98aa242efac6b47326a0857ca8/Benchmarks/HummingbirdBenchmarks/URLEncodedFormBenchmarks.swift)
include both encoding and decoding with array fields. Cookie parsing and direct
array-valued form encode/decode were gaps here and now have fixtures.

Their [PerformanceTest server](https://github.com/hummingbird-project/hummingbird/blob/e027f279b5bdba98aa242efac6b47326a0857ca8/Sources/PerformanceTest/main.swift)
provides text, JSON, streamed POST echo and a delayed handler for external wrk runs.
Our external harness already adds warmups, repeated/rotated comparisons, response
validation and provenance. It now includes collected and streamed POST echoes and
known-length/chunked response streams with varied write sizes.

Their [benchmark workflow](https://github.com/hummingbird-project/hummingbird/blob/e027f279b5bdba98aa242efac6b47326a0857ca8/.github/workflows/benchmark.yml)
compares a PR with main and reports instruction/allocation deltas. That is useful
future automation once this suite lands on main. Keep shared-CI execution as a
correctness smoke test; use a controlled host for credible performance thresholds
and retain the toolchain, dependency locks and counter availability with results.

## Coverage added in this review

- Matched 1 KiB buffered responses between tiny and large payloads.
- Request streams collected into a buffered echo, or forwarded as read, with both
  content-length and chunked uploads. The counter client yields sixteen 4 KiB chunks.
- Response streams with known/unknown lengths, plus one 64 KiB write versus 256
  writes of 256 B. Both responder and real-network layers consume complete bodies.
- External wrk workloads for streamed response shapes and both upload handlers,
  matched across Vapor, raw HTTP server, Vapor 4 and Hummingbird.
- Complete body validation for responder fixtures and framing checks for common
  network response streams. Draining fixtures now run in the default counter pass.
- Cookie parsing and direct array-valued URL-encoded form encoding/decoding.

## Remaining priorities

1. **Backpressure and bounded memory:** large uploads/downloads with an intentionally
   slow producer/reader, time to first byte, peak/resident memory and cancellation.
   A 64 KiB payload and eager collecting client do not establish bounded-memory
   behavior. Add these as separate sustained scenarios with explicit pacing;
   wall time dominated by sleeps would obscure the current per-operation counters.
2. **Deployment protocols:** TLS handshakes versus reused TLS connections, HTTP/2
   multiplexing, compression and connection churn. Current results describe
   plaintext HTTP/1.1 keep-alive only.
3. **Application combinations:** JSON decode/encode over a socket, multipart uploads,
   authenticated/session requests with existing cookies, and an active metrics or
   tracing backend. Isolated content/auth/session fixtures already cover much of
   this work, but do not measure every interaction in a real request.
4. **Capacity measurements:** a separate load-generator machine and a fixed-arrival-rate
   client to explore tail latency near saturation. Local closed-loop wrk results
   include host contention and are not an open-loop service-level latency model.

Database, template and external-service latency belong in application benchmarks
with separately defined dependencies. They should not be folded into a framework
baseline whose purpose is to explain changes in Vapor itself.

## Validation of this revision

On macOS with Apple Swift 6.4:

- Release builds passed for Benchmarks, Performance and Performance/Comparisons.
- All 169 counter fixtures passed in `BENCHMARK_SMOKE=1` mode, including all four
  upload variants on each network target and the response-framing assertions.
- Eleven shared HTTP workloads passed on all four servers: 44 short measured
  samples, with no HTTP/socket errors or timeouts and no forced server shutdown.
- Eight Python harness tests passed, including POST body validation and rejection
  of unsupported streaming routes in direct-responder mode.
- The repository formatter and strict lint passed for all 25 Swift files changed
  by the branch; `git diff --check` passed.

The HTTP runs used one second each for warmup and measurement, one repeat and four
connections. They verify the fixtures and harness, not a framework performance
ranking. Linux execution remains for CI. Regenerate network counter baselines:
the measured loop now includes fresh client request construction.
