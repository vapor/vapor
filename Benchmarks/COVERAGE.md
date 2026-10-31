# Benchmark coverage

The package measures the current Vapor checkout at three levels:

| Layer | Purpose | Measurement boundary |
| --- | --- | --- |
| Component fixtures | Identify changes in allocations, instructions and elapsed time for individual operations | Routing/trie lookup, requests, content, authentication, middleware, responses, serialization, macros and writers |
| `e2e.` | Measure a complete responder invocation | Fresh request, routing, default middleware, encoding and complete body consumption into a copying sink |
| `network.` and `drain-network.` | Exercise the HTTP path and request/response streaming | In-process client and server, serial plaintext HTTP/1.1 loopback requests and keep-alive reuse |

The responder fixtures do not include sockets or HTTP framing. The network
fixtures include both client and server work; their counters cannot be attributed
to the server alone. They measure individual requests rather than concurrent
throughput or capacity under load.

Allocation counts, instructions, process CPU time and elapsed time are measured in
separate modes using the same fixtures. Only allocation mode enables the malloc
interposer. Normal measurements use five warmups and a five-second runtime cap;
smoke mode keeps one unscaled sample with no warmup.

Session creation removes each created session after measurement. Session updates
reuse one seeded entry with a fixed cookie and value. Application state therefore
stays bounded across warmups and samples; fixture setup/teardown runs only once.

## Streaming coverage

- Known-length and chunked responses with sixteen 1 KiB writes.
- A fixed 64 KiB response written once or in 256 awaited writes.
- Known-length and chunked uploads, produced in sixteen 4 KiB chunks, that are
  either collected into a buffered echo or forwarded as they are read.
- Unread uploads followed by server draining and connection reuse.

Response and upload fixtures validate complete bodies before timing. Network
stream fixtures also validate response framing. Transport may coalesce application
chunks, so a client's yield count does not prescribe server read boundaries.

## Remaining scenarios

- Sustained large uploads/downloads with a slow producer or reader, time to first
  byte, peak/resident memory and cancellation. Current eager clients and small
  payloads do not establish bounded-memory behavior under backpressure.
- TLS handshakes and reused connections, HTTP/2 multiplexing, compression and
  connection churn.
- Combined application paths such as JSON decode/encode over a socket, multipart
  uploads, combined authentication/session requests and an active metrics or tracing backend.

Paced or sustained scenarios should use separate configurations: wall time
dominated by deliberate delays would obscure the current per-operation counters.
The test workflow runs every fixture in smoke mode to validate correctness. The
shared benchmark workflow runs all four measurement modes on its controlled runner
and compares against reviewed p90 thresholds. Manually dispatch with
`record_thresholds` enabled to generate the initial values on that runner. Normal
runs fail until they have been committed. Keep toolchains and dependencies
consistent when comparing results.
