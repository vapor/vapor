import NIOWebSocket

/// Represents a client connected via WebSocket protocol.
/// Use this to receive text/data frames and send responses.
///
///      ws.onText { ws, string in
///         ws.send(string.reversed())
///      }
///
public final class WebSocket {
    /// Available WebSocket modes. Either `Client` or `Server`.
    public enum Mode {
        /// Uses socket in `Client` mode
        case client
        
        /// Uses socket in `Server` mode
        case server
        
        /// RFC 6455 Section 5.1
        /// To avoid confusing network intermediaries (such as intercepting proxies) and
        /// for security reasons that are further, a client MUST mask all frames that it
        /// sends to the server.
        /// The server MUST close the connection upon receiving a frame that is not masked.
        /// A server MUST NOT mask any frames that it sends to the client.
        /// A client MUST close a connection if it detects a masked frame.
        ///
        /// RFC 6455 Section 5.3
        /// The masking key is a 32-bit value chosen at random by the client.
        /// When preparing a masked frame, the client MUST pick a fresh masking
        /// key from the set of allowed 32-bit values.
        internal func makeMaskKey() -> WebSocketMaskingKey? {
            switch self {
            case .client:
                return WebSocketMaskingKey([.anyRandom, .anyRandom, .anyRandom, .anyRandom])
            case .server:
                return  nil
            }
        }
    }
    
    /// See `BasicWorker`.
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }
    
    /// Outbound `WebSocketEventHandler`.
    private let channel: Channel
    
    /// `WebSocket` processing mode.
    internal let mode: Mode
    
    /// See `onText(...)`.
    var onTextCallback: (WebSocket, String) -> ()
    
    /// See `onBinary(...)`.
    var onBinaryCallback: (WebSocket, [UInt8]) -> ()
    
    /// See `onError(...)`.
    var onErrorCallback: (WebSocket, Error) -> ()
    
    /// See `onCloseCode(...)`.
    var onCloseCodeCallback: (WebSocketErrorCode) -> ()
    
    /// Creates a new `WebSocket` using the supplied `Channel` and `Mode`.
    /// Use `httpProtocolUpgrader(...)` to create a protocol upgrader that can create `WebSocket`s.
    public init(channel: Channel, mode: Mode) {
        self.channel = channel
        self.mode = mode
        self.isClosed = false
        self.onTextCallback = { _, _ in }
        self.onBinaryCallback = { _, _ in }
        self.onErrorCallback = { _, _ in }
        self.onCloseCodeCallback = { _ in }
    }
    
    // MARK: Receive
    
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
    public func onText(_ callback: @escaping (WebSocket, String) -> ()) {
        onTextCallback = callback
    }
    
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
    public func onBinary(_ callback: @escaping (WebSocket, [UInt8]) -> ()) {
        onBinaryCallback = callback
    }
    
    /// Adds a callback to this `WebSocket` to handle errors.
    ///
    ///     ws.onError { ws, error in
    ///         print(error)
    ///     }
    ///
    /// - parameters:
    ///     - callback: Closure to handle error's caught during this connection.
    public func onError(_ callback: @escaping (WebSocket, Error) -> ()) {
        onErrorCallback = callback
    }
    
    /// Adds a callback to this `WebSocket` to handle incoming close codes.
    ///
    ///     ws.onCloseCode { closeCode in
    ///         print(closeCode)
    ///     }
    ///
    /// - parameters:
    ///     - callback: Closure to handle received close codes.
    public func onCloseCode(_ callback: @escaping (WebSocketErrorCode) -> ()) {
        onCloseCodeCallback = callback
    }
    
    // MARK: Send
    
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
        let string = String(text)
        var buffer = channel.allocator.buffer(capacity: text.count)
        buffer.writeString(string)
        self.send(buffer, opcode: .text, fin: true, promise: promise)
        
    }
    
    /// Sends binary-formatted data to the connected client.
    ///
    ///     ws.onText { ws, string in
    ///         ws.send([0x68, 0x69])
    ///     }
    ///
    /// - parameters:
    ///     - text: `Data` to send as binary-formatted data to the client.
    ///     - promise: Optional `Promise` to complete when the send is finished.
    public func send(binary: [UInt8], promise: EventLoopPromise<Void>? = nil) {
        self.send(raw: binary, opcode: .binary, promise: promise)
    }
    
    /// Sends raw-data to the connected client using the supplied WebSocket opcode.
    ///
    ///     // client will receive "Hello, world!" as one message
    ///     ws.send(raw: "Hello, ", opcode: .text, fin: false)
    ///     ws.send(raw: "world", opcode: .continuation, fin: false)
    ///     ws.send(raw: "!", opcode: .continuation)
    ///
    /// - parameters:
    ///     - data: `LosslessDataConvertible` to send to the client.
    ///     - opcode: `WebSocketOpcode` indicating data format. Usually `.text` or `.binary`.
    ///     - fin: If `false`, additional `.continuation` frames are expected.
    ///     - promise: Optional `Promise` to complete when the send is finished.
    public func send(raw data: [UInt8], opcode: WebSocketOpcode, fin: Bool = true, promise: EventLoopPromise<Void>? = nil) {
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        self.send(buffer, opcode: opcode, fin: fin, promise: promise)
    }
    
    // MARK: Close
    
    /// `true` if the `WebSocket` has been closed.
    public internal(set) var isClosed: Bool
    
    /// A `Future` that will be completed when the `WebSocket` closes.
    public var onClose: EventLoopFuture<Void> {
        return channel.closeFuture
    }
    
    /// Closes the `WebSocket`'s connection, disconnecting the client.
    ///
    /// - parameters:
    ///     - code: Optional `WebSocketCloseCode` to send before closing the connection.
    ///             If a code is provided, the WebSocket will wait until an acknowledgment is
    ///             received from the server before actually closing the connection.
    public func close(code: WebSocketErrorCode? = nil) {
        guard !isClosed else {
            return
        }
        self.isClosed = true
        if let code = code {
            sendClose(code: code)
        } else {
            channel.close(promise: nil)
        }
    }
    
    // MARK: Private
    
    /// Private just send close code.
    private func sendClose(code: WebSocketErrorCode) {
        var buffer = channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: code)
        send(buffer, opcode: .connectionClose, fin: true, promise: nil)
    }
    
    /// Private send that accepts a raw `WebSocketFrame`.
    private func send(_ buffer: ByteBuffer, opcode: WebSocketOpcode, fin: Bool, promise: EventLoopPromise<Void>?) {
        guard !self.isClosed else { return }
        let frame = WebSocketFrame(
            fin: fin,
            opcode: opcode,
            maskKey: mode.makeMaskKey(),
            data: buffer
        )
        channel.writeAndFlush(frame, promise: promise)
    }
}

private extension FixedWidthInteger {
    static var anyRandom: Self {
        return Self.random(in: Self.min..<Self.max)
    }
}
