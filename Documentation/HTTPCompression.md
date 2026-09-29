# HTTP compression migration

Response compression and request decompression are separate public middleware. Register `ResponseCompressionMiddleware` to compress responses, and `RequestDecompressionMiddleware` to decode requests. Neither is installed automatically; setting server configuration alone does not enable either feature. Both work with HTTP/1.1, HTTP/2, and in-memory tests without installing channel handlers.

Request decoding is lazy. A decompressed stream emits bounded chunks, and body collection still enforces the selected route's limit against the expanded bytes. The server retains its original reader for bounded draining. Response encoding runs as responses travel back through the middleware chain; streaming writes await the transport, and failures abort the response without writing a successful terminator.

`Content-Encoding` and `Content-Length` are removed from decoded requests. Exceeding a decompression limit now returns 413 instead of closing the connection without an HTTP response. Invalid or incomplete compressed bodies return 400 when consumed before a response is sent. A failure discovered while writing a streaming response aborts that response.

## Vapor-owned API

Enable either direction by registering its middleware before starting the application:

```swift
// Compress known compressible response types, including error responses.
app.middleware.use(app.makeResponseCompressionMiddleware(), at: .beginning)

// Optionally decode gzip/deflate requests with a 25:1 expansion limit.
app.middleware.use(app.makeRequestDecompressionMiddleware())
```

The application factories copy the current server settings. To customize them, configure the settings before creating the middleware:

```swift
app.serverConfiguration.requestDecompression.limit = .size(2_000_000)
app.serverConfiguration.responseCompression.mediaTypes = .only(.compressible)

app.middleware.use(app.makeResponseCompressionMiddleware(), at: .beginning)
app.middleware.use(app.makeRequestDecompressionMiddleware())
```

Place response compression before `ErrorMiddleware` (using `at: .beginning` with the default application chain) to also compress error responses. Place request decompression after error middleware and before other middleware that reads bodies. This allows decoding errors to become HTTP responses and makes decoded bodies available to downstream consumers.

For independent settings, construct `ResponseCompressionMiddleware(configuration:)` or `RequestDecompressionMiddleware(configuration:)` directly; both also have useful no-argument defaults. To limit compression or decompression to a route group, pass the desired middleware to `app.grouped(...)`. Group middleware only wraps that group's routes; compressing responses from application-level error middleware requires application-level response compression. Custom responders can be wrapped explicitly using `makeResponder(chainingTo:)`.

To leave a route uncompressed, register response compression on a group and declare that route outside the group:

```swift
// Register the compressor on this group instead of app.middleware.
let compressed = app.grouped(app.makeResponseCompressionMiddleware())
compressed.get("compressed") { _ in
    "This response can be compressed."
}

app.get("uncompressed") { _ in
    "This response stays uncompressed."
}
```

Application-level middleware wraps every route, including routes declared directly on `app`. When some routes must stay uncompressed, use group registration as above. Separate groups can use different `ResponseCompressionMiddleware(configuration:)` settings. Request decompression can still be registered globally or scoped to its own groups independently.

Request configuration describes the decompression limit, defaulting to `.ratio(25)`. `.size(_:)`, `.ratio(_:)`, and `.none` belong to `ServerConfiguration.RequestDecompressionConfiguration.DecompressionLimit`. No NIO type appears in this API. A ratio is checked against compressed bytes received so far, matching the previous incremental semantics. `.none` removes the decompression limit, but does not remove a route's collection limit.

Response configuration describes the media type policy and buffer capacity. The default `.only(.compressible)` policy compresses known compressible content types. Use `.excluding(.incompressible)` to compress everything except known incompressible types, or `.excluding(.none)` to allow all types (including responses without a content type).

Neither configuration has an enabled/disabled state. Leave the corresponding middleware out of the chain to turn that behavior off.

The previous route override helper and internal marker header have been removed; middleware placement controls where compression applies. Negotiation supports gzip and zlib-wrapped deflate. Encoded variants add `Vary: Accept-Encoding` and weaken strong ETags. Already encoded, empty, partial, HEAD, and bodyless-status responses are not compressed.

The configuration types belong to Vapor. If further configuration is needed, add Vapor-owned coding and compression-level value types with private backend conversion. Avoid accepting a backend's configuration type or introducing a public backend-selection API. `initialByteBufferCapacity` controls the output chunk capacity, bounded internally between 64 bytes and 64 KiB.

## Optional dependency

The `Compression` package trait is enabled by default. This makes the APIs available; registration enables their behavior. Disabling the trait removes the server compression API, middleware, codecs, and Vapor's zlib target dependency. The HTTP client retains its existing, separately managed decompression support.

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

Tests use the manifest's HTTP Server 0.2.0 dependency, with an unmodified dependency checkout. On macOS with Swift 6.4:

- Default traits: 633 tests across the library, macros, and macro integration targets.
- All default traits disabled: 543 tests.
- Only `Compression` enabled: 564 tests.

All three configurations completed successfully, with the same four pre-existing known issues concerning verified peer certificate chains and connection closure. A compression-only full-suite run during earlier validation crashed with `Deinited NIOAsyncWriter without calling finish()`. It did not recur in these runs; the cause of that intermittent crash has not been isolated.

The compression tests cover independent middleware registration, configuration without registration, default settings, route-group scoping and policies, compressed error responses, the migrated content-type matrix, HTTP/1.1 and HTTP/2, gzip and deflate, byte and ratio limits, chunked input, streamed output, response metadata, malformed bodies, and producer failures. WebSocket and UNIX-socket tests remain deferred. Linux was not executed locally.
