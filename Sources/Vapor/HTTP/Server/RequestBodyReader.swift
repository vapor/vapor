/// Anchors a ``RequestBodyReader``'s (non-escapable) lifetime. ``Request/Body/withReader(_:)`` makes one
/// as a local and lends it to the reader; when the call returns the token dies and the reader with it,
/// so the reader can't be stashed and read after the request moved on.
struct RequestBodyReaderScope: ~Copyable {
    init() {}
}

/// Reads an HTTP request body, pulled straight off the connection with backpressure (the server stops
/// reading until the handler asks for more). Implementations come from the HTTP server layer.
///
/// **Non-escapable**: valid only for the duration of the ``Request/Body/withReader(_:)`` closure it was
/// lent to, so the body can't be read after the request moved on and "read it twice" is a compile-time error.
public protocol RequestBodyReader: ~Escapable {
    /// Reads the next part of the body, handing its bytes to `body` as a borrowed ``RawSpan`` along
    /// with a flag that is `true` once the body has ended (in which case the span is empty).
    ///
    /// The span is only valid for the duration of `body`; copy out anything you need to keep.
    func read<R>(_ body: (RawSpan, Bool) async throws -> R) async throws -> R
}

extension RequestBodyReader where Self: ~Escapable {
    /// Reads the whole remaining body, calling `body` once per chunk in order, until it ends.
    ///
    /// The span handed to `body` is only valid for that call; copy out anything you need to keep.
    @inlinable
    public func forEachChunk(_ body: (RawSpan) async throws -> Void) async throws {
        while true {
            let ended = try await self.read { span, isEnd -> Bool in
                guard !isEnd else {
                    return true
                }
                try await body(span)
                return false
            }
            if ended {
                return
            }
        }
    }
}
