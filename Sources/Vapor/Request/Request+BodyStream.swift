extension Request {
    final class BodyStream: BodyStreamWriter {
        /// Handles an incoming `HTTPChunkedStreamResult`.
        typealias Handler = (BodyStreamResult) -> ()
        
        /// If `true`, this `HTTPChunkedStream` has already sent an `end` chunk.
        private(set) var isClosed: Bool
        
        /// This stream's `HTTPChunkedHandler`, if one is set.
        private var handler: Handler?
        
        /// If a `handler` has not been set when `write(_:)` is called, this property
        /// is used to store the waiting data.
        private var buffer: [BodyStreamResult]
        
        /// Creates a new `HTTPChunkedStream`.
        ///
        /// - parameters:
        ///     - worker: `Worker` to complete futures on.
        init() {
            self.isClosed = false
            self.buffer = []
        }
        
        /// Sets a handler for reading `HTTPChunkedStreamResult`s from the stream.
        ///
        ///     chunkedStream.read { res, stream in
        ///         print(res) // prints the chunk
        ///         return .done(on: stream) // you can do async work or just return done
        ///     }
        ///
        /// - parameters:
        ///     - handler: `HTTPChunkedHandler` to use for receiving chunks from this stream.
        func read(_ handler: @escaping Handler) {
            self.handler = handler
            for item in self.buffer {
                handler(item)
            }
            self.buffer = []
        }
        
        /// Writes a `HTTPChunkedStreamResult` to the stream.
        ///
        ///     try chunkedStream.write(.end).wait()
        ///
        /// You must wait for the returned `Future` to complete before writing additional data.
        ///
        /// - parameters:
        ///     - chunk: A `HTTPChunkedStreamResult` to write to the stream.
        /// - returns: A `Future` that will be completed when the write was successful.
        ///            You must wait for this future to complete before calling `write(_:)` again.
        func write(_ chunk: BodyStreamResult) {
            if case .end = chunk {
                self.isClosed = true
            }
            
            if let handler = handler {
                handler(chunk)
            } else {
                self.buffer.append(chunk)
            }
        }
        
        /// Reads all `HTTPChunkedStreamResult`s from this stream until `end` is received.
        /// The output is combined into a single `Data`.
        ///
        ///     let data = try stream.drain(max: ...).wait()
        ///     print(data) // Data
        ///
        /// - parameters:
        ///     - max: The maximum number of bytes to allow before throwing an error.
        ///            Use this to prevent using excessive memory on your server.
        /// - returns: `Future` containing the collected `Data`.
        func consume(max: Int, on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
            let promise = eventLoop.makePromise(of: ByteBuffer.self)
            var data = ByteBufferAllocator().buffer(capacity: 0)
            self.read { chunk in
                switch chunk {
                case .buffer(var buffer):
                    if data.readableBytes + buffer.readableBytes >= max {
                        promise.fail(Abort(.payloadTooLarge))
                    } else {
                        data.writeBuffer(&buffer)
                    }
                case .error(let error): promise.fail(error)
                case .end: promise.succeed(data)
                }
            }
            return promise.futureResult
        }
    }
}
