public enum BodyStreamResult {
    /// A normal data chunk.
    /// There will be 0 or more of these.
    case buffer(ByteBuffer)
    /// Indicates an error.
    /// There will be 0 or 1 of these. 0 if the stream closes cleanly.
    case error(Error)
    /// Indicates the stream has completed.
    /// There will be 0 or 1 of these. 0 if the stream errors.
    case end
}

public protocol BodyStreamWriter {
    var eventLoop: EventLoop { get }
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?)
}

extension BodyStreamWriter{
    public func write(_ result: BodyStreamResult) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.write(result, promise: promise)
        return promise.futureResult
    }
}
