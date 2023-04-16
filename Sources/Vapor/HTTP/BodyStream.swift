import NIOCore

public enum BodyStreamResult: Sendable {
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

extension BodyStreamResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .buffer(let buffer):
            return "buffer(\(buffer.readableBytes) bytes)"
        case .error(let error):
            return "error(\(error))"
        case .end:
            return "end"
        }
    }
}

extension BodyStreamResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .buffer(let buffer):
            let value = String(decoding: buffer.readableBytesView, as: UTF8.self)
            return "buffer(\(value))"
        case .error(let error):
            return "error(\(error))"
        case .end:
            return "end"
        }
    }
}

public protocol BodyStreamWriter {
    var eventLoop: EventLoop { get }
    func write(_ result: BodyStreamResult, promise: EventLoopPromise<Void>?)
}

extension BodyStreamWriter {
    public func write(_ result: BodyStreamResult) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.write(result, promise: promise)
        return promise.futureResult
    }
}
