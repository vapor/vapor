import NIO
import NIOWebSocket

extension ChannelPipeline {
    /// Adds the supplied `WebSocket` to this `ChannelPipeline`.
    public func add(webSocket: WebSocket) -> EventLoopFuture<Void> {
        let handler = WebSocketHandler(webSocket: webSocket)
        return self.addHandler(handler)
    }
}

// MARK: Private

/// Decodes `WebSocketFrame`s, forwarding to a `WebSocket`.
private final class WebSocketHandler: ChannelInboundHandler {
    /// See `ChannelInboundHandler`.
    typealias InboundIn = WebSocketFrame
    
    /// See `ChannelInboundHandler`.
    typealias OutboundOut = WebSocketFrame
    
    /// `WebSocket` to handle the incoming events.
    private var webSocket: WebSocket
    
    /// Current frame sequence.
    private var frameSequence: WebSocketFrameSequence?
    
    /// Creates a new `WebSocketEventDecoder`
    init(webSocket: WebSocket) {
        self.webSocket = webSocket
    }
    
    /// See `ChannelInboundHandler`.
    func channelActive(context: ChannelHandlerContext) {
        // connected
    }
    
    /// See `ChannelInboundHandler`.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var frame = self.unwrapInboundIn(data)
        switch frame.opcode {
        case .connectionClose: self.receivedClose(context: context, frame: frame)
        case .ping:
            if !frame.fin {
                closeOnError(context: context) // control frames can't be fragmented it should be final
            } else {
                pong(context: context, frame: frame)
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
        if var frameSequence = self.frameSequence, frame.fin {
            switch frameSequence.type {
            case .binary:
                #warning("TODO: pass buffered results")
            // webSocket.onBinaryCallback(webSocket, frameSequence.binaryBuffer?.readBytes(length: frameSequence.binaryBuffer?.readableBytes ?? 0) ?? [])
            case .text: webSocket.onTextCallback(webSocket, frameSequence.textBuffer)
            default: break
            }
            self.frameSequence = nil
        }
    }
    
    /// See `ChannelInboundHandler`.
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        webSocket.onErrorCallback(webSocket, error)
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
            maskKey: webSocket.mode.makeMaskKey(),
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
            maskKey: webSocket.mode.makeMaskKey(),
            data: data
        )
        
        _ = context.writeAndFlush(self.wrapOutboundOut(frame)).flatMap {
            context.close(mode: .output)
        }
        self.webSocket.isClosed = true
    }
}
