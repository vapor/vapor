//import NIO
//import NIOWebSocket
//
//internal final class HTTPServerWebSocket {
//    private let channel: Channel
//    var eventLoop: EventLoop {
//        return self.channel.eventLoop
//    }
//    var onTextCallback: (HTTPServerWebSocket, String) -> ()
//    var onBinaryCallback: (HTTPServerWebSocket, ByteBuffer) -> ()
//    var onErrorCallback: (HTTPServerWebSocket, Error) -> ()
//    var isClosed: Bool {
//        return !self.channel.isActive
//    }
//    var onClose: EventLoopFuture<Void> {
//        return self.channel.closeFuture
//    }
//
//    init(channel: Channel) {
//        self.channel = channel
//        self.onTextCallback = { _, _ in }
//        self.onBinaryCallback = { _, _ in }
//        self.onErrorCallback = { _, _ in }
//    }
//
//    internal func send(_ buffer: ByteBuffer, opcode: WebSocketOpcode, fin: Bool, promise: EventLoopPromise<Void>?) {
//        guard !self.isClosed else { return }
//        let frame = WebSocketFrame(
//            fin: fin,
//            opcode: opcode,
//            maskKey: nil,
//            data: buffer
//        )
//        self.channel.writeAndFlush(frame, promise: promise)
//    }
//
//    deinit {
//        assert(self.isClosed, "WebSocket deinitialized before closing.")
//    }
//}
//
//extension HTTPServerWebSocket: WebSocket {
//    func send(binary: ByteBuffer, promise: EventLoopPromise<Void>?) {
//        self.send(binary, opcode: .binary, fin: true, promise: promise)
//    }
//
//    func send(text: String, promise: EventLoopPromise<Void>?) {
//        var buffer = self.channel.allocator.buffer(capacity: text.utf8.count)
//        buffer.writeString(text)
//        self.send(buffer, opcode: .text, fin: true, promise: promise)
//    }
//
//    func close(code: WebSocketErrorCode?, promise: EventLoopPromise<Void>?) {
//        guard !self.isClosed else {
//            return
//        }
//        if let code = code {
//            var buffer = self.channel.allocator.buffer(capacity: 2)
//            buffer.write(webSocketErrorCode: code)
//            self.send(buffer, opcode: .connectionClose, fin: true, promise: nil)
//        } else {
//            self.channel.close(promise: promise)
//        }
//    }
//
//
//    func onText(_ callback: @escaping (WebSocket, String) -> ()) {
//        self.onTextCallback = callback
//    }
//
//
//    func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
//        self.onBinaryCallback = callback
//    }
//
//    func onError(_ callback: @escaping (WebSocket, Error) -> ()) {
//        self.onErrorCallback = callback
//    }
//}
//
///// Decodes `WebSocketFrame`s, forwarding to a `WebSocket`.
//internal final class HTTPServerWebSocketHandler: ChannelInboundHandler {
//    /// See `ChannelInboundHandler`.
//    typealias InboundIn = WebSocketFrame
//
//    /// See `ChannelInboundHandler`.
//    typealias OutboundOut = WebSocketFrame
//
//    /// `WebSocket` to handle the incoming events.
//    private var webSocket: HTTPServerWebSocket
//
//    /// Current frame sequence.
//    private var frameSequence: WebSocketFrameSequence?
//
//    /// Creates a new `WebSocketEventDecoder`
//    init(webSocket: HTTPServerWebSocket) {
//        self.webSocket = webSocket
//    }
//
//    /// See `ChannelInboundHandler`.
//    func channelActive(context: ChannelHandlerContext) {
//        // connected
//    }
//
//    /// See `ChannelInboundHandler`.
//    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        let frame = self.unwrapInboundIn(data)
//        switch frame.opcode {
//        case .connectionClose: self.receivedClose(context: context, frame: frame)
//        case .ping:
//            if !frame.fin {
//                self.closeOnError(context: context) // control frames can't be fragmented it should be final
//            } else {
//                self.pong(context: context, frame: frame)
//            }
//        case .text, .binary:
//            // create a new frame sequence or use existing
//            var frameSequence: WebSocketFrameSequence
//            if let existing = self.frameSequence {
//                frameSequence = existing
//            } else {
//                frameSequence = WebSocketFrameSequence(type: frame.opcode)
//            }
//            // append this frame and update the sequence
//            frameSequence.append(frame)
//            self.frameSequence = frameSequence
//        case .continuation:
//            // we must have an existing sequence
//            if var frameSequence = self.frameSequence {
//                // append this frame and update
//                frameSequence.append(frame)
//                self.frameSequence = frameSequence
//            } else {
//                self.closeOnError(context: context)
//            }
//        default:
//            // We ignore all other frames.
//            break
//        }
//
//        // if this frame was final and we have a non-nil frame sequence,
//        // output it to the websocket and clear storage
//        if let frameSequence = self.frameSequence, frame.fin {
//            switch frameSequence.type {
//            case .binary:
//                self.webSocket.onBinaryCallback(self.webSocket, frameSequence.binaryBuffer)
//            case .text:
//                self.webSocket.onTextCallback(self.webSocket, frameSequence.textBuffer)
//            default: break
//            }
//            self.frameSequence = nil
//        }
//    }
//
//    /// See `ChannelInboundHandler`.
//    func errorCaught(context: ChannelHandlerContext, error: Error) {
//        self.webSocket.onErrorCallback(self.webSocket, error)
//    }
//
//    /// Closes gracefully.
//    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
//        /// Parse the close frame.
//        var data = frame.unmaskedData
//        if let closeCode = data.readInteger(as: UInt16.self)
//            .map(Int.init)
//            .flatMap(WebSocketErrorCode.init(codeNumber:))
//        {
//            self.webSocket.onErrorCallback(self.webSocket, closeCode)
//        }
//
//        // Handle a received close frame. In websockets, we're just going to send the close
//        // frame and then close, unless we already sent our own close frame.
//        if self.webSocket.isClosed {
//            // Cool, we started the close and were waiting for the user. We're done.
//            context.close(promise: nil)
//        } else {
//            // This is an unsolicited close. We're going to send a response frame and
//            // then, when we've sent it, close up shop. We should send back the close code the remote
//            // peer sent us, unless they didn't send one at all.
//            let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
//            _ = context.writeAndFlush(wrapOutboundOut(closeFrame)).whenComplete { _ in
//                _ = context.close(promise: nil)
//            }
//        }
//    }
//
//    /// Sends a pong frame in response to ping.
//    private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
//        let pongFrame = WebSocketFrame(
//            fin: true,
//            opcode: .pong,
//            maskKey: nil,
//            data: frame.data
//        )
//        context.writeAndFlush(self.wrapOutboundOut(pongFrame), promise: nil)
//    }
//
//    /// Closes the connection with error frame.
//    private func closeOnError(context: ChannelHandlerContext) {
//        // We have hit an error, we want to close. We do that by sending a close frame and then
//        // shutting down the write side of the connection.
//        var data = context.channel.allocator.buffer(capacity: 2)
//        let error = WebSocketErrorCode.protocolError
//        data.write(webSocketErrorCode: error)
//        let frame = WebSocketFrame(
//            fin: true,
//            opcode: .connectionClose,
//            maskKey: nil,
//            data: data
//        )
//
//        _ = context.writeAndFlush(self.wrapOutboundOut(frame)).flatMap {
//            context.close(mode: .output)
//        }
//    }
//}
//
//extension WebSocketErrorCode: Error { }
//
///// Collects WebSocket frame sequences.
/////
///// See https://tools.ietf.org/html/rfc6455#section-5 below.
/////
///// 5.  Data Framing
///// 5.1.  Overview
/////
///// In the WebSocket Protocol, data is transmitted using a sequence of
///// frames.  To avoid confusing network intermediaries (such as
///// intercepting proxies) and for security reasons that are further
///// discussed in Section 10.3, a client MUST mask all frames that it
///// sends to the server (see Section 5.3 for further details).  (Note
///// that masking is done whether or not the WebSocket Protocol is running
///// over TLS.)  The server MUST close the connection upon receiving a
///// frame that is not masked.  In this case, a server MAY send a Close
///// frame with a status code of 1002 (protocol error) as defined in
///// Section 7.4.1.  A server MUST NOT mask any frames that it sends to
///// the client.  A client MUST close a connection if it detects a masked
///// frame.  In this case, it MAY use the status code 1002 (protocol
///// error) as defined in Section 7.4.1.  (These rules might be relaxed in
///// a future specification.)
/////
///// The base framing protocol defines a frame type with an opcode, a
///// payload length, and designated locations for "Extension data" and
///// "Application data", which together define the "Payload data".
///// Certain bits and opcodes are reserved for future expansion of the
///// protocol.
/////
///// A data frame MAY be transmitted by either the client or the server at
///// any time after opening handshake completion and before that endpoint
///// has sent a Close frame (Section 5.5.1).
//private struct WebSocketFrameSequence {
//    var binaryBuffer: ByteBuffer
//    var textBuffer: String
//    var type: WebSocketOpcode
//
//    init(type: WebSocketOpcode) {
//        self.binaryBuffer = ByteBufferAllocator().buffer(capacity: 0)
//        self.textBuffer = .init()
//        self.type = type
//    }
//
//    mutating func append(_ frame: WebSocketFrame) {
//        var data = frame.unmaskedData
//        switch type {
//        case .binary:
//            self.binaryBuffer.writeBuffer(&data)
//        case .text:
//            self.textBuffer += data.readString(length: data.readableBytes) ?? ""
//        default: break
//        }
//    }
//}
