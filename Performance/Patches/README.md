# HTTP-server batching experiment

`swift-http-server-batched-send.patch` applies to swift-http-server **0.2.0**,
commit `9b75bce220c97a2078eda303f6c11de376a29755`.

The patch overrides `NIOHTTPServer.ResponseSender.sendAndFinish` to send a buffered
response's head, optional body, and end through one `NIOAsyncChannelOutboundWriter.write(contentsOf:)`
call. The released implementation inherits the protocol default, which writes the head,
body, and end separately. SwiftNIO schedules and flushes each write. Hummingbird already
uses the batched operation for buffered responses.

The patch preserves the existing body conversion, empty-body behavior, trailers, the
informational-status precondition, and the writer-completion latch. Streaming `send`/`write`/
`finish` behavior is unchanged. Regression tests cover buffered bodies, trailers, buffer
draining, completion state, generic protocol dispatch, and the status precondition.

This is a local experimental patch, not a published dependency release or submitted PR.
The normal `Performance/` package is restored to the unmodified release. The saved patched
executables under `Performance/.build/ab/batched/` are ignored build artifacts. The source
patch and recorded measurements are the durable deliverables.

## Reproduction

From the repository root, first build and save both stock products (`PerformanceServer`
and `HTTPServerPerformanceServer`) using `swift build --package-path Performance -c release
--product PRODUCT`. Use a separate directory for each variant; do not overwrite stock
executables when building the candidate.

Create a separate checkout, apply the patch, and temporarily select it:

```sh
git clone --branch 0.2.0 https://github.com/swift-server/swift-http-server.git /tmp/swift-http-server-perf
git -C /tmp/swift-http-server-perf apply "$PWD/Performance/Patches/swift-http-server-batched-send.patch"
swift package --package-path Performance edit swift-http-server --path /tmp/swift-http-server-perf
```

Build the same two products again and save them in the candidate directory. Restore the
released dependency afterward, including if a build fails:

```sh
swift package --package-path Performance unedit swift-http-server
```

Rebuild the normal products after restoring. `Package.resolved` in the results records the
versions used for the study; restore those versions to reproduce it. A fresh dependency
resolution may choose newer transitive dependencies.

Compare the snapshots with `compare.py --skip-build --binary FRAMEWORK=PATH`. The study used
`vapor`, `vapor-batched`, `http-server`, and `http-server-batched`, along with the released
Vapor 4 and Hummingbird adapters. All builds and tests finished before measured load began.

The validation commands, in the patched HTTP-server checkout, were:

```sh
swift test --filter 'NIOHTTPServerResponseSenderTests|NIOHTTPServerWriterTests|NIOHTTPServerEndToEndTests'
swift test --skip-build --filter 'HTTPKeepAliveHandlerTests|ConnectionLifecycleTests|ConnectionBackpressureEndToEndTests'
```

These passed 27 tests across six suites, including parameterized cases and HTTP/1.1/HTTP/2
integration checks. This does not claim HTTP/3 performance or validation with HTTP/3 traits enabled.
