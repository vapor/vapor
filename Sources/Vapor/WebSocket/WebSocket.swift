import NIOWebSocket

/// Represents a client connected via WebSocket protocol.
/// Use this to receive text/data frames and send responses.
///
///      ws.onText { ws, string in
///         ws.send(string.reversed())
///      }
///
public protocol WebSocket {
    /// Adds a callback to this `WebSocket` to receive text-formatted messages.
    ///
    ///     ws.onText { ws, string in
    ///         ws.send(string.reversed())
    ///     }
    ///
    /// Use `onBinary(_:)` to handle binary-formatted messages.
    ///
    /// - parameters:
    ///     - callback: Closure to accept incoming text-formatted data.
    ///                 This will be called every time the connected client sends text.
    func onText(_ callback: @escaping (WebSocket, String) -> ())

    /// Adds a callback to this `WebSocket` to receive binary-formatted messages.
    ///
    ///     ws.onBinary { ws, data in
    ///         print(data)
    ///     }
    ///
    /// Use `onText(_:)` to handle text-formatted messages.
    ///
    /// - parameters:
    ///     - callback: Closure to accept incoming binary-formatted data.
    ///                 This will be called every time the connected client sends binary-data.
    func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ())

    /// Adds a callback to this `WebSocket` to handle errors.
    ///
    ///     ws.onError { ws, error in
    ///         print(error)
    ///     }
    ///
    /// - parameters:
    ///     - callback: Closure to handle error's caught during this connection.
    func onError(_ callback: @escaping (WebSocket, Error) -> ())

    func send(binary: ByteBuffer, promise: EventLoopPromise<Void>?)
    func send(text: String, promise: EventLoopPromise<Void>?)

    var onClose: EventLoopFuture<Void> { get }
    func close(code: WebSocketErrorCode?, promise: EventLoopPromise<Void>?)
}

extension WebSocket {
    public func send(binary: ByteBuffer) {
        self.send(binary: binary, promise: nil)
    }

    public func send(text: String) {
        self.send(text: text, promise: nil)
    }

    public func close(promise: EventLoopPromise<Void>?) {
        self.close(code: nil, promise: promise)
    }

    public func close(code: WebSocketErrorCode?) {
        self.close(code: code, promise: nil)
    }

    public func close() {
        self.close(code: nil, promise: nil)
    }

    /// Sends text-formatted data to the connected client.
    ///
    ///     ws.onText { ws, string in
    ///         ws.send(string.reversed())
    ///     }
    ///
    /// - parameters:
    ///     - text: `String` to send as text-formatted data to the client.
    ///     - promise: Optional `Promise` to complete when the send is finished.
    public func send<S>(text: S, promise: EventLoopPromise<Void>? = nil) where S: Collection, S.Element == Character {
        self.send(text: String(text), promise: promise)
    }
}
