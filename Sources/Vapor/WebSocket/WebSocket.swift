import NIO
import NIOWebSocket
@_exported import enum NIOWebSocket.WebSocketErrorCode

/// Represents a client connected via WebSocket protocol.
/// Use this to receive text/data frames and send responses.
///
///      ws.onText { ws, string in
///         ws.send(string.reversed())
///      }
///
public final class WebSocket {
    public static func connect(
        to url: URI,
        headers: HTTPHeaders = [:],
        on eventLoop: EventLoopGroup,
        onUpgrade: @escaping (WebSocket) -> ()
    ) -> EventLoopFuture<Void> {
        return self.connect(
            ClientRequest(method: .GET, url: url, headers: headers, body: nil),
            on: eventLoop,
            onUpgrade: onUpgrade
        )
    }

    static func connect(
        _ request: ClientRequest,
        on eventLoop: EventLoopGroup,
        onUpgrade: @escaping (WebSocket) -> ()
    ) -> EventLoopFuture<Void> {
        let port: Int
        if let p = request.url.port {
            port = p
        } else if let scheme = request.url.scheme {
            port = scheme == "wss" ? 443 : 80
        } else {
            port = 80
        }
        return self.connect(
            host: request.url.host ?? "",
            port: port,
            uri: request.url.path,
            headers: request.headers,
            tlsConfiguration: request.url.scheme == "wss" ? .forClient() : nil,
            on: eventLoop
        ) { socket in
            onUpgrade(socket)
        }
    }

    static func connect(
        host: String,
        port: Int,
        uri: String = "/",
        headers: HTTPHeaders = [:],
        tlsConfiguration: TLSConfiguration?,
        on eventLoop: EventLoopGroup,
        onUpgrade: @escaping (WebSocket) -> ()
    ) -> EventLoopFuture<Void> {
        return WebSocketClient(eventLoopGroupProvider: .shared(eventLoop), configuration: .init(
            tlsConfiguration: tlsConfiguration,
            maxFrameSize: 1 << 14
        )).connect(host: host, port: port, uri: uri, headers: headers, onUpgrade: onUpgrade)
    }

    public var eventLoop: EventLoop {
        return channel.eventLoop
    }

    /// Outbound `WebSocketEventHandler`.
    private let channel: Channel

    /// See `onText(...)`.
    var onTextCallback: (WebSocket, String) -> ()

    /// See `onBinary(...)`.
    var onBinaryCallback: (WebSocket, ByteBuffer) -> ()

    /// See `onPong(...)`.
    var onPongCallback: (WebSocket, ByteBuffer) -> ()

    /// See `onError(...)`.
    var onErrorCallback: (WebSocket, Error) -> ()

    /// See `onCloseCode(...)`.
    var onCloseCodeCallback: (WebSocketErrorCode) -> ()

    /// Creates a new `WebSocket` using the supplied `Channel` and `Mode`.
    /// Use `httpProtocolUpgrader(...)` to create a protocol upgrader that can create `WebSocket`s.
    init(channel: Channel) {
        self.channel = channel
        self.onTextCallback = { _, _ in }
        self.onBinaryCallback = { _, _ in }
        self.onPongCallback = { _, _ in }
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
        self.onTextCallback = callback
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
    public func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
        self.onBinaryCallback = callback
    }

    /// Adds a callback to this `WebSocket` to handle pong.
    ///
    ///     ws.onPong { ws, data in
    ///         print(data)
    ///     }
    ///
    /// - parameters:
    ///     - callback: Closure to accept incoming pong.
    ///                 This will be called every time the connected client sends pong.
    public func onPong(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
        self.onPongCallback = callback
    }

    /// Adds a callback to this `WebSocket` to handle errors.
    ///
    ///     ws.onError { ws, error in
    ///         print(error)
    ///     }
    ///
    /// - parameters:
    ///     - callback: Closure to handle error's caught during this connection.
    public func onError(_ callback: @escaping (WebSocket, Swift.Error) -> ()) {
        self.onErrorCallback = callback
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
        self.onCloseCodeCallback = callback
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
    public func send<S>(_ text: S, promise: EventLoopPromise<Void>? = nil) where S: Collection, S.Element == Character {
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
    public func send(_ binary: [UInt8], promise: EventLoopPromise<Void>? = nil) {
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

    /// `true` if the `WebSocket` has been closed.
    public var isClosed: Bool {
        return !self.channel.isActive
    }

    /// A `Future` that will be completed when the `WebSocket` closes.
    public var onClose: EventLoopFuture<Void> {
        return self.channel.closeFuture
    }

    public func close(code: WebSocketErrorCode? = nil) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        self.close(code: code, promise: promise)
        return promise.futureResult
    }

    public func close(code: WebSocketErrorCode? = nil, promise: EventLoopPromise<Void>?) {
        guard !self.isClosed else {
            promise?.succeed(())
            return
        }
        if let code = code {
            self.sendClose(code: code)
        }
        self.channel.close(mode: .all, promise: promise)
    }

    // MARK: Internal

    func addHandler(to pipeline: ChannelPipeline) -> EventLoopFuture<Void> {
        return pipeline.addHandler(WebSocketHandler(webSocket: self))
    }

    internal func makeMaskKey() -> WebSocketMaskingKey? {
        return WebSocketMaskingKey([UInt8].random(count: 4))
    }

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
            maskKey: self.makeMaskKey(),
            data: buffer
        )
        self.channel.writeAndFlush(frame, promise: promise)
    }

    deinit {
        assert(self.isClosed, "WebSocket was not closed before deinit.")
    }
}

// MARK: Private

private final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    private var webSocket: WebSocket
    private var frameSequence: WebSocketFrameSequence?

    init(webSocket: WebSocket) {
        self.webSocket = webSocket
    }

    func channelActive(context: ChannelHandlerContext) {
        // connected
    }

    /// See `ChannelInboundHandler`.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        switch frame.opcode {
        case .connectionClose:
            self.receivedClose(context: context, frame: frame)
        case .ping:
            if !frame.fin {
                closeOnError(context: context) // control frames can't be fragmented it should be final
            } else {
                pong(context: context, frame: frame)
            }
        case .pong:
            if !frame.fin {
                closeOnError(context: context) // control frames can't be fragmented it should be final
            } else {
                self.webSocket.onPongCallback(self.webSocket, frame.unmaskedData)
            }
        case .text, .binary:
            // create a new frame sequence or use existing
            var frameSequence: WebSocketFrameSequence
            if let existing = self.frameSequence {
                frameSequence = existing
            } else {
                frameSequence = WebSocketFrameSequence(type: frame.opcode)
            }
            // append this frame and update the sequence
            frameSequence.append(frame)
            self.frameSequence = frameSequence
        case .continuation:
            // we must have an existing sequence
            if var frameSequence = self.frameSequence {
                // append this frame and update
                frameSequence.append(frame)
                self.frameSequence = frameSequence
            } else {
                self.closeOnError(context: context)
            }
        default:
            // We ignore all other frames.
            break
        }

        // if this frame was final and we have a non-nil frame sequence,
        // output it to the websocket and clear storage
        if let frameSequence = self.frameSequence, frame.fin {
            switch frameSequence.type {
            case .binary:
                self.webSocket.onBinaryCallback(self.webSocket, frameSequence.binaryBuffer)
            case .text:
                self.webSocket.onTextCallback(self.webSocket, frameSequence.textBuffer)
            default: break
            }
            self.frameSequence = nil
        }
    }

    /// See `ChannelInboundHandler`.
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.webSocket.onErrorCallback(webSocket, error)
    }

    /// Closes gracefully.
    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        /// Parse the close frame.
        var data = frame.unmaskedData
        if let closeCode = data.readInteger(as: UInt16.self)
            .map(Int.init)
            .flatMap(WebSocketErrorCode.init(codeNumber:))
        {
            webSocket.onCloseCodeCallback(closeCode)
        }

        // Handle a received close frame. In websockets, we're just going to send the close
        // frame and then close, unless we already sent our own close frame.
        if webSocket.isClosed {
            // Cool, we started the close and were waiting for the user. We're done.
            context.close(promise: nil)
        } else {
            // This is an unsolicited close. We're going to send a response frame and
            // then, when we've sent it, close up shop. We should send back the close code the remote
            // peer sent us, unless they didn't send one at all.
            let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
            _ = context.writeAndFlush(wrapOutboundOut(closeFrame)).whenComplete { _ in
                _ = context.close(promise: nil)
            }
        }
    }

    /// Sends a pong frame in response to ping.
    private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
        let pongFrame = WebSocketFrame(
            fin: true,
            opcode: .pong,
            maskKey: webSocket.makeMaskKey(),
            data: frame.data
        )
        context.writeAndFlush(self.wrapOutboundOut(pongFrame), promise: nil)
    }

    /// Closes the connection with error frame.
    private func closeOnError(context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close frame and then
        // shutting down the write side of the connection.
        var data = context.channel.allocator.buffer(capacity: 2)
        let error = WebSocketErrorCode.protocolError
        data.write(webSocketErrorCode: error)
        let frame = WebSocketFrame(
            fin: true,
            opcode: .connectionClose,
            maskKey: webSocket.makeMaskKey(),
            data: data
        )

        _ = context.writeAndFlush(self.wrapOutboundOut(frame)).flatMap {
            context.close(mode: .output)
        }
    }
}

/// Collects WebSocket frame sequences.
///
/// See https://tools.ietf.org/html/rfc6455#section-5 below.
///
/// 5.  Data Framing
/// 5.1.  Overview
///
/// In the WebSocket Protocol, data is transmitted using a sequence of
/// frames.  To avoid confusing network intermediaries (such as
/// intercepting proxies) and for security reasons that are further
/// discussed in Section 10.3, a client MUST mask all frames that it
/// sends to the server (see Section 5.3 for further details).  (Note
/// that masking is done whether or not the WebSocket Protocol is running
/// over TLS.)  The server MUST close the connection upon receiving a
/// frame that is not masked.  In this case, a server MAY send a Close
/// frame with a status code of 1002 (protocol error) as defined in
/// Section 7.4.1.  A server MUST NOT mask any frames that it sends to
/// the client.  A client MUST close a connection if it detects a masked
/// frame.  In this case, it MAY use the status code 1002 (protocol
/// error) as defined in Section 7.4.1.  (These rules might be relaxed in
/// a future specification.)
///
/// The base framing protocol defines a frame type with an opcode, a
/// payload length, and designated locations for "Extension data" and
/// "Application data", which together define the "Payload data".
/// Certain bits and opcodes are reserved for future expansion of the
/// protocol.
///
/// A data frame MAY be transmitted by either the client or the server at
/// any time after opening handshake completion and before that endpoint
/// has sent a Close frame (Section 5.5.1).
private struct WebSocketFrameSequence {
    var binaryBuffer: ByteBuffer
    var textBuffer: String
    var type: WebSocketOpcode

    init(type: WebSocketOpcode) {
        self.binaryBuffer = ByteBufferAllocator().buffer(capacity: 0)
        self.textBuffer = .init()
        self.type = type
    }

    mutating func append(_ frame: WebSocketFrame) {
        var data = frame.unmaskedData
        switch type {
        case .binary:
            self.binaryBuffer.writeBuffer(&data)
        case .text:
            if let string = data.readString(length: data.readableBytes) {
                self.textBuffer += string
            }
        default: break
        }
    }
}
