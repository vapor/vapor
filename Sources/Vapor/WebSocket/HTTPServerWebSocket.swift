import NIOWebSocket

internal final class HTTPServerWebSocket {
    enum Mode {
        case client
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
                return WebSocketMaskingKey([.random, .random, .random, .random])
            case .server:
                return  nil
            }
        }
    }

    private let channel: Channel
    internal let mode: Mode
    var onTextCallback: (HTTPServerWebSocket, String) -> ()
    var onBinaryCallback: (HTTPServerWebSocket, ByteBuffer) -> ()
    var onErrorCallback: (HTTPServerWebSocket, Error) -> ()
    var isClosed: Bool {
        return !self.channel.isActive
    }
    var onClose: EventLoopFuture<Void> {
        return self.channel.closeFuture
    }

    init(channel: Channel, mode: Mode) {
        self.channel = channel
        self.mode = mode
        self.onTextCallback = { _, _ in }
        self.onBinaryCallback = { _, _ in }
        self.onErrorCallback = { _, _ in }
    }

    internal func send(_ buffer: ByteBuffer, opcode: WebSocketOpcode, fin: Bool, promise: EventLoopPromise<Void>?) {
        guard !self.isClosed else { return }
        let frame = WebSocketFrame(
            fin: fin,
            opcode: opcode,
            maskKey: mode.makeMaskKey(),
            data: buffer
        )
        self.channel.writeAndFlush(frame, promise: promise)
    }

    deinit {
        assert(self.isClosed, "WebSocket deinitialized before closing.")
    }
}

extension HTTPServerWebSocket: WebSocket {
    func send(binary: ByteBuffer, promise: EventLoopPromise<Void>?) {
        self.send(binary, opcode: .binary, fin: true, promise: promise)
    }

    func send(text: String, promise: EventLoopPromise<Void>?) {
        var buffer = self.channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        self.send(buffer, opcode: .text, fin: true, promise: promise)
    }

    func close(code: WebSocketErrorCode?, promise: EventLoopPromise<Void>?) {
        guard !self.isClosed else {
            return
        }
        if let code = code {
            var buffer = self.channel.allocator.buffer(capacity: 2)
            buffer.write(webSocketErrorCode: code)
            self.send(buffer, opcode: .connectionClose, fin: true, promise: nil)
        } else {
            self.channel.close(promise: promise)
        }
    }


    func onText(_ callback: @escaping (WebSocket, String) -> ()) {
        self.onTextCallback = callback
    }


    func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
        self.onBinaryCallback = callback
    }

    func onError(_ callback: @escaping (WebSocket, Error) -> ()) {
        self.onErrorCallback = callback
    }
}


private extension FixedWidthInteger {
    static var random: Self {
        return Self.random(in: Self.min..<Self.max)
    }
}
