#if compiler(>=5.5) && canImport(_Concurrency)

extension Request {
    /// Access a stream of `ByteBuffer`s from a `Request.Body`
    public var asyncByteBufferStream: AsyncThrowingStream<ByteBuffer, Error> {
        return AsyncThrowingStream { continuation in
            self.body.drain { streamResult in
                switch streamResult {
                case .buffer(let byteBuffer):
                    continuation.yield(byteBuffer)
                case .error(let error):
                    continuation.finish(throwing: error)
                case .end:
                    continuation.finish()
                }
                return self.eventLoop.makeSucceededVoidFuture()
            }
        }
    }
}

#endif
