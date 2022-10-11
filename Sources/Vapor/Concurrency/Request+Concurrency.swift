#if compiler(>=5.5) && canImport(_Concurrency)
import AsyncAlgorithms

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension Request {
    /// Access a async channel of `ByteBuffer`s from a `Request.Body`.
    ///
    /// This `AsyncThrowingChannel` property works similiarly to `AsyncStream` / `AsyncThrowingStream` except it supports backpressure.  [See Documentation](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md).
    ///
    /// Example Usage:
    ///
    /// routes.swift:
    /// ```
    /// app.on(.POST, "upload",
    ///     body: .stream,
    ///     use: streamController.upload)
    /// ```
    ///
    /// StreamController.swift upload func:
    /// ```
    /// let channel = req.asyncThrowingChannel
    /// for try await byteBuffer in channel {
    ///    print(byteBuffer.readablebytes)
    /// }
    /// ```
    ///
    /// **Warning** The efficient usage of this property is reliant on the `Request`’s route using `body: .stream` otherwise the default body of `.collect` will read inbound requests to memory.
    public var asyncThrowingChannel: AsyncThrowingChannel<ByteBuffer, any Error> {
        let channel = AsyncThrowingChannel<ByteBuffer, any Error>(ByteBuffer.self)
        
        self.body.drain { streamResult in
            Task {
                switch streamResult {
                case .buffer(let byteBuffer):
                    await channel.send(byteBuffer)
                case .error(let error):
                    await channel.fail(error)
                case .end:
                    channel.finish()
                }
            }
            return self.eventLoop.makeSucceededVoidFuture()
        }
        
        return channel
    }
}

#endif
