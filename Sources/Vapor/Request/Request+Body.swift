extension Request {
    public struct Body: CustomStringConvertible {
        let request: Request
        
        init(_ request: Request) {
            self.request = request
        }
        
        public var data: ByteBuffer? {
            switch self.request.bodyStorage {
            case .collected(let buffer): return buffer
            case .none, .stream: return nil
            }
        }

        public var string: String? {
            if var data = self.data {
                return data.readString(length: data.readableBytes)
            } else {
                return nil
            }
        }
        
        public func drain(_ handler: @escaping (BodyStreamResult) -> EventLoopFuture<Void>) {
            switch self.request.bodyStorage {
            case .stream(let stream):
                stream.read { (result, promise) in
                    handler(result).cascade(to: promise)
                }
            case .collected(let buffer):
                _ = handler(.buffer(buffer))
            case .none: break
            }
        }
        
        /// Consumes the body if it is a stream. Otherwise, returns the same value as the `data` property.
        ///
        ///     let data = try httpRes.body.consumeData(max: 1_000_000, on: ...).wait()
        ///
        /// - parameters:
        ///     - max: The maximum streaming body size to allow.
        ///            This only applies to streaming bodies, like chunked streams.
        ///            Defaults to 1MB.
        ///     - eventLoop: The event loop to perform this async work on.
        public func collect(max: Int? = nil) -> EventLoopFuture<ByteBuffer?> {
            switch self.request.bodyStorage {
            case .stream(let stream):
                return stream.consume(max: max, on: self.request.eventLoop).map { buffer in
                    self.request.bodyStorage = .collected(buffer)
                    return buffer
                }
            case .collected(let buffer):
                return self.request.eventLoop.makeSucceededFuture(buffer)
            case .none:
                return self.request.eventLoop.makeSucceededFuture(nil)
            }
        }
        
        public var description: String {
            return ""
        }
    }
}
