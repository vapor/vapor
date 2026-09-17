# HTTP compression migration

Compression runs in a private middleware around the responder chain. It does not install handlers on the HTTP server's channels. The same implementation therefore applies to HTTP/1.1, HTTP/2, custom responders, and in-memory tests.

Request decoding is lazy and precedes routing. A decompressed stream emits bounded chunks, and body collection still enforces the selected route's limit against the expanded bytes. The server retains its original reader for bounded draining. Response encoding runs after route overrides and error middleware; streaming writes await the transport, and failures abort the response without writing a successful terminator.

`Content-Encoding` and `Content-Length` are removed from decoded requests. Exceeding a decompression limit now returns 413 instead of closing the connection without an HTTP response. Invalid or incomplete compressed bodies return 400 when consumed before a response is sent. A failure discovered while writing a streaming response aborts that response.

## Vapor-owned API

Configure compression before starting the application:

```swift
app.serverConfiguration.requestDecompression = .enabled(limit: .size(2_000_000))
app.serverConfiguration.responseCompression = .enabledForCompressibleTypes

app.responseCompression(.disable).get("uncompressed") { _ in
    "This route opts out."
}
```

Request decoding defaults to `.disabled`. The `.enabled` shorthand uses `.ratio(25)`; `.size(_:)`, `.ratio(_:)`, and `.none` belong to `ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit`. No NIO type appears in this API. A ratio is checked against compressed bytes received so far, matching the previous incremental semantics. `.none` removes the decompression limit, but does not remove a route's collection limit.

Response encoding retains the existing Vapor policy type: `.disabled`, `.forceDisabled`, `.enabledForCompressibleTypes`, and `.enabled`, plus allowlists, denylists, and route overrides. The internal marker is removed before a response leaves the middleware. Negotiation supports gzip and zlib-wrapped deflate. Encoded variants add `Vary: Accept-Encoding` and weaken strong ETags. Already encoded, empty, partial, HEAD, and bodyless-status responses are not compressed.

Keeping the existing policy names makes migration small. If further configuration is needed, add Vapor-owned coding and compression-level value types with private backend conversion. Avoid accepting a backend's configuration type or introducing a public backend-selection API. `initialByteBufferCapacity` is retained for migration compatibility; its role is the output chunk capacity, bounded internally between 64 bytes and 64 KiB. A future API could name this `outputBufferSize`, or leave buffer sizing entirely internal.

## Optional dependency

The `Compression` package trait is enabled by default. Disabling it removes the server compression API, middleware, codecs, and Vapor's zlib target dependency. The HTTP client retains its existing, separately managed decompression support.

Examples for this checkout:

```sh
swift test
swift test --disable-default-traits
swift test --disable-default-traits --traits Compression
```

The current backend uses the system zlib through a two-file module shim. No zlib source is vendored into Vapor. On Linux, building with the trait requires zlib development headers (for example, `zlib1g-dev` on Debian/Ubuntu); Apple's SDK supplies them on macOS.

## Evaluation of brokenhandsio/compression

Inspected [revision 809d1b9c607d382c3de30e4c0ed09bfc43c7a606](https://github.com/brokenhandsio/compression/tree/809d1b9c607d382c3de30e4c0ed09bfc43c7a606). `swift build` succeeded with Swift 6.4 on macOS. Its deployment targets fit Vapor, and its gzip/zlib formats cover the required encodings.

It is promising, but its public streaming API is not a complete replacement for this adapter yet:

- The [streaming decompressor protocol](https://github.com/brokenhandsio/compression/blob/809d1b9c607d382c3de30e4c0ed09bfc43c7a606/Sources/CompressionCore/StreamingDecompressor.swift) exposes neither completion nor a finalization operation. Vapor needs to distinguish a complete compressed body from transport EOF before the compressed body finished.
- The [deflate streaming decoder](https://github.com/brokenhandsio/compression/blob/809d1b9c607d382c3de30e4c0ed09bfc43c7a606/Sources/Zlib/DeflateStreamingDecompressor.swift) does not report input consumption. Vapor needs this to account for remaining input at the end of the compressed stream.
- The callbacks are synchronous and use the codec's typed error. They cannot directly await an HTTP writer or propagate an arbitrary transport error. The compressor could be adapted by feeding bounded input slices and buffering their output, but a pull-based decoder also needs control over how much output is produced in one operation.
- The streaming decoder's configuration has a size-limit property, but its streaming implementation does not apply it. Vapor's byte and ratio policies must still be enforced incrementally, before decoded output is retained.

The smallest useful upstream addition is a bounded step API accepting an input span and an output buffer, returning consumed input, produced output, and a status such as needs-input / needs-output / finished. EOF validation should be explicit. An async sink API with caller-defined errors is another option. These would let Vapor replace the codec without changing its public configuration or middleware integration.

The package is not added as a dependency in this change. Importing its C module directly would still leave Vapor responsible for the zlib adapter while coupling it to the package's implementation details. This evaluation was source review and a compatibility build; no upstream reports or changes were submitted.

## Validation

Tests use the manifest's HTTP Server 0.2.0 dependency in an isolated build directory, without the existing workspace's local HTTP-server edit. On macOS with Swift 6.4:

- Default traits: 660 tests across the library, macros, and macro integration targets.
- All default traits disabled: 542 tests.
- Only `Compression` enabled: 591 tests.

All suites pass, with the same four pre-existing known issues concerning verified peer certificate chains and connection closure. The compression tests cover the migrated content-type and override matrix, HTTP/1.1 and HTTP/2, gzip and deflate, byte and ratio limits, chunked input, streamed output, response metadata, malformed bodies, and producer failures. WebSocket and UNIX-socket tests remain deferred. Linux was not executed locally.
