# HTTP-server bottleneck investigation — 17 September 2026

The principal identified bottleneck is **the missing batched implementation of
`NIOHTTPServer.ResponseSender.sendAndFinish`** in swift-http-server 0.2.0. Vapor already
calls that API for buffered responses, but the server inherits the protocol's default
implementation, which writes the response head, body, and end separately.

A 17-line server implementation change improves current Vapor's measured throughput by
**25–29%** across the three buffered workloads tested. Vapor's framework source was not
changed. This explains a substantial part of the earlier gap; it does not establish that
all remaining differences have the same cause.

## Layer isolation

Three five-second samples per cell, with two-second discarded warm-ups, 64 connections,
four `wrk` threads, and four NIO event-loop threads. Values are median requests/sec.

| Configuration | Tiny, 2 B | Buffered, 64 KiB |
| --- | ---: | ---: |
| Current Vapor | 59,478 | 35,531 |
| Vapor without middleware | 60,108 | 34,027 |
| Vapor custom responder, bypassing router and middleware | 61,437 | 34,553 |
| HTTP server alone | 60,112 | 34,803 |
| Hummingbird 2.26.0 | 77,161 | 42,250 |
| Vapor 4.122.1 | 73,254 | 44,115 |

Removing routing and middleware does not recover the gap in this configuration. The HTTP
server alone has essentially the same throughput ceiling. This does not mean routing is
free; it means routing is not the dominant throughput constraint in this test.

[Isolation ranges and latency](Results/2026-09-17-isolation/summary.md) ·
[Individual samples](Results/2026-09-17-isolation/results.json)

## Mechanism

The released `HTTPResponseSender` default expands `sendAndFinish` into `send`, then
`Writer.finish`. The NIO implementation does:

```swift
try await writer.write(.head(response))
try await writer.write(.body(buffer))
try await writer.write(.end(trailers))
```

Each `NIOAsyncChannelOutboundWriter.write` submits work to the event loop and flushes.
Thus an ordinary nonempty buffered response incurs three submissions/flush attempts.
This does **not** imply exactly three kernel writes: an end with Content-Length can have
no wire bytes, and the transport can coalesce work.

The patch supplies the intended fast path:

```swift
try await writer.write(contentsOf: [.head(response), .body(buffer), .end(trailers)])
```

That submits the complete response in one batch and flushes once. Empty bodies omit the
body part. The completion latch is set after the write succeeds, as before. Hummingbird
already uses this strategy in its buffered response writer.

The patch retains the same `UniqueArray` → `ByteBuffer` conversion. Therefore the measured
improvement comes from batching, not from eliminating the body copy. The extra copying
remains a possible future optimization, but this study does not quantify its independent cost.

A separate 15-second Time Profiler recording of stock Vapor under tiny-response load found
the leaf `write` syscall in **17.31%** of running samples, and the outbound event-loop write
path in **27.66%**. The router appeared in **9.49%** of inclusive samples. These percentages
overlap and must not be summed; they describe sampled call stacks, not exclusive per-request
CPU costs. Profiling was separate from all throughput measurements.

[Stock CPU profile summary](Results/2026-09-17-isolation/stock-profile-summary.json)

A matching patched-profile attempt reached its recording limit but Instruments did not
finish stopping within the 90-second tool timeout. It is excluded from the analysis;
there is no claimed before/after CPU-percentage comparison. The throughput runs completed
separately and are unaffected by that profiling failure.

## Controlled before/after comparison

Stock and patched executables were saved separately, identified by SHA-256, and measured
in the same run with rotated order. Both use the same framework and dependency revisions;
the only production-source difference in the candidate is the server method above.
These measurements were taken after the isolation run, so their stock baselines differ.

| Workload | Vapor stock | Vapor patched | Change | Vapor 4 | Hummingbird |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tiny | 66,247 | 83,914 | +26.7% | 73,505 | 85,764 |
| 64 KiB | 36,232 | 45,152 | +24.6% | 47,157 | 44,568 |
| JSON, 48 B | 60,761 | 78,417 | +29.1% | 71,121 | 82,802 |

The same patch also improves the standalone HTTP server:

| Workload | HTTP server stock | HTTP server patched | Change |
| --- | ---: | ---: | ---: |
| Tiny | 63,172 | 83,122 | +31.6% |
| 64 KiB | 37,177 | 44,376 | +19.4% |
| JSON | 65,511 | 86,316 | +31.8% |

The completed A/B run has **54 measurements, 17,678,850 measured requests, and zero reported
socket/status errors or timeouts**, including all warm-ups. Every response body was validated
before load; JSON was validated by decoded value and content type.

Median p50 latency falls in all three Vapor cases. Median per-run p99 does not uniformly
improve: tiny changes from 1.979 to 2.122 ms, large from 2.316 to 2.025 ms, and JSON from
2.767 to 2.732 ms. Higher saturation throughput is not a claim about p99 at fixed arrival rate.

[A/B ranges and latency](Results/2026-09-17-batched-ab/summary.md) ·
[Every sample](Results/2026-09-17-batched-ab/results.json) ·
[Binary hashes and machine settings](Results/2026-09-17-batched-ab/metadata.json) ·
[Patch provenance](Results/2026-09-17-batched-ab/experiment.json)

## Streaming controls

`sendAndFinish` is used for buffered responses. The streaming writer is unchanged, so
streaming/file routes are useful controls. Three repeated samples gave:

| Workload | Vapor stock | Vapor patched | Change |
| --- | ---: | ---: | ---: |
| 16 × 1 KiB stream | 14,744 | 14,620 | −0.8% |
| Cached 1 MiB file | 4,375 | 4,356 | −0.4% |

These changes are small relative to the buffered gains. This short laptop experiment is
not precise enough to establish whether sub-percent changes are real regressions.
All 12 measured samples and their warm-ups completed without reported errors.

[Control results and latency](Results/2026-09-17-stream-controls/summary.md)

## Patch, validation, and remaining work

The [reviewable patch](Patches/swift-http-server-batched-send.patch) targets swift-http-server
0.2.0, revision `9b75bce220c97a2078eda303f6c11de376a29755`. Its regression tests plus selected
upstream tests passed **27 tests across six suites**, including parameterized bodies/trailers,
generic protocol dispatch, empty responses, writer completion, HTTP/1.1 and HTTP/2 integration,
keep-alive, connection lifecycle, and backpressure. HTTP/3 traits were not enabled or validated.

[Response and protocol test log](Results/2026-09-17-isolation/batching-response-tests.log) ·
[Connection and backpressure test log](Results/2026-09-17-isolation/batching-connection-tests.log)

The normal Performance package and its regular release executables have been restored to
the **unmodified** released dependency. The improved numbers require the saved experimental
executables or applying the patch. Nothing was published or submitted upstream.
See [reproduction instructions](Patches/README.md).

All measurements used the same M1 Pro laptop, macOS 27, Swift 6.4, plaintext HTTP/1.1, and
POSIX transport. The client and server shared the machine. No builds, tests, or profiler ran
alongside measured load. Some tail-latency outliers remain; the raw data records them.

The next useful step is to validate this small server patch on dedicated Linux hardware,
with a separate load generator and a concurrency sweep. Then profile the remaining JSON
and 64 KiB differences after batching: patched Vapor is still about 5% behind Hummingbird
on JSON and 4% behind Vapor 4 on 64 KiB in this run. Their causes have not been isolated here.
