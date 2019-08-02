import NIOWebSocket

internal final class HTTPServerWebSocket {
    private let channel: Channel
    var eventLoop: EventLoop {
        return self.channel.eventLoop
    }
    var onTextCallback: (HTTPServerWebSocket, String) -> ()
    var onBinaryCallback: (HTTPServerWebSocket, ByteBuffer) -> ()
    var onErrorCallback: (HTTPServerWebSocket, Error) -> ()
    var isClosed: Bool {
        return !self.channel.isActive
    }
    var onClose: EventLoopFuture<Void> {
        return self.channel.closeFuture
    }

    init(channel: Channel) {
        self.channel = channel
        self.onTextCallback = { _, _ in }
        self.onBinaryCallback = { _, _ in }
        self.onErrorCallback = { _, _ in }
    }

    internal func send(_ buffer: ByteBuffer, opcode: WebSocketOpcode, fin: Bool, promise: EventLoopPromise<Void>?) {
        guard !self.isClosed else { return }
        let frame = WebSocketFrame(
            fin: fin,
            opcode: opcode,
            maskKey: nil,
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

