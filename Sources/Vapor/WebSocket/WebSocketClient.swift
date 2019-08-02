import Foundation
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1
import NIOWebSocket
import NIOSSL

public final class WebSocketClient {
    public enum Error: Swift.Error, LocalizedError {
        case invalidResponseStatus(HTTPResponseHead)
        case alreadyShutdown
        public var errorDescription: String? {
            return "\(self)"
        }
    }

    public enum EventLoopGroupProvider {
        case shared(EventLoopGroup)
        case createNew
    }

    public struct Configuration {
        public var tlsConfiguration: TLSConfiguration?
        public var maxFrameSize: Int

        public init(
            tlsConfiguration: TLSConfiguration? = nil,
            maxFrameSize: Int = 1 << 14
        ) {
            self.tlsConfiguration = tlsConfiguration
            self.maxFrameSize = maxFrameSize
        }
    }

    /// Represents a client connected via WebSocket protocol.
    /// Use this to receive text/data frames and send responses.
    ///
    ///      ws.onText { ws, string in
    ///         ws.send(string.reversed())
    ///      }
    ///
    public final class Socket {
        public var eventLoop: EventLoop {
            return channel.eventLoop
        }

        /// Outbound `WebSocketEventHandler`.
        private let channel: Channel

        /// See `onText(...)`.
        var onTextCallback: (Socket, String) -> ()

        /// See `onBinary(...)`.
        var onBinaryCallback: (Socket, ByteBuffer) -> ()

        /// See `onError(...)`.
        var onErrorCallback: (Socket, Swift.Error) -> ()

        /// See `onCloseCode(...)`.
        var onCloseCodeCallback: (WebSocketErrorCode) -> ()

        /// Creates a new `WebSocket` using the supplied `Channel` and `Mode`.
        /// Use `httpProtocolUpgrader(...)` to create a protocol upgrader that can create `WebSocket`s.
        init(channel: Channel) {
            self.channel = channel
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
        public func onText(_ callback: @escaping (Socket, String) -> ()) {
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
        public func onBinary(_ callback: @escaping (Socket, ByteBuffer) -> ()) {
            self.onBinaryCallback = callback
        }

        /// Adds a callback to this `WebSocket` to handle errors.
        ///
        ///     ws.onError { ws, error in
        ///         print(error)
        ///     }
        ///
        /// - parameters:
        ///     - callback: Closure to handle error's caught during this connection.
        public func onError(_ callback: @escaping (Socket, Swift.Error) -> ()) {
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

        // MARK: Private

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

    let eventLoopGroupProvider: EventLoopGroupProvider
    let group: EventLoopGroup
    let configuration: Configuration
    let isShutdown = Atomic<Bool>(value: false)

    public init(eventLoopGroupProvider: EventLoopGroupProvider, configuration: Configuration = .init()) {
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch self.eventLoopGroupProvider {
        case .shared(let group):
            self.group = group
        case .createNew:
            self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        }
        self.configuration = configuration
    }

    public func connect(
        host: String,
        port: Int,
        uri: String = "/",
        headers: HTTPHeaders = [:],
        onUpgrade: @escaping (Socket) -> ()
    ) -> EventLoopFuture<Void> {
        let upgradePromise: EventLoopPromise<Void> = self.group.next().makePromise(of: Void.self)
        let bootstrap = ClientBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
            .channelInitializer { channel in
                let httpEncoder = HTTPRequestEncoder()
                let httpDecoder = ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes))
                let webSocketUpgrader = WebSocketClientUpgradeHandler(
                    configuration: self.configuration,
                    host: host,
                    uri: uri,
                    upgradePromise: upgradePromise
                ) { channel, response in
                    let webSocket = Socket(channel: channel)
                    return channel.pipeline.removeHandler(httpEncoder).flatMap {
                        return channel.pipeline.removeHandler(httpDecoder)
                    }.flatMap {
                        let handler = WebSocketClientHandler(webSocket: webSocket)
                        return channel.pipeline.addHandler(handler)
                    }.map {
                        onUpgrade(webSocket)
                    }
                }
                var handlers: [ChannelHandler] = []
                if let tlsConfiguration = self.configuration.tlsConfiguration {
                    let context = try! NIOSSLContext(configuration: tlsConfiguration)
                    let tlsHandler = try! NIOSSLClientHandler(context: context, serverHostname: host)
                    handlers.append(tlsHandler)
                }
                handlers += [httpEncoder, httpDecoder, webSocketUpgrader]
                return channel.pipeline.addHandlers(handlers)
            }

        let connect = bootstrap.connect(host: host, port: port)
        connect.cascadeFailure(to: upgradePromise)
        return connect.flatMap { channel in
            return upgradePromise.futureResult.flatMap {
                return channel.closeFuture
            }
        }
    }


    public func syncShutdown() throws {
        switch self.eventLoopGroupProvider {
        case .shared:
            self.isShutdown.store(true)
            return
        case .createNew:
            if self.isShutdown.compareAndExchange(expected: false, desired: true) {
                try self.group.syncShutdownGracefully()
            } else {
                throw WebSocketClient.Error.alreadyShutdown
            }
        }
    }

    deinit {
        switch self.eventLoopGroupProvider {
        case .shared:
            return
        case .createNew:
            assert(self.isShutdown.load(), "WebSocketClient not shutdown before deinit.")
        }
    }
}

extension WebSocketClient {
    public func webSocket(_ url: URI, headers: HTTPHeaders = [:], onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Void> {
        return self.webSocket(ClientRequest(method: .GET, url: url, headers: headers, body: nil), onUpgrade: onUpgrade)
    }
    
    public func webSocket(_ request: ClientRequest, onUpgrade: @escaping (WebSocket) -> ()) -> EventLoopFuture<Void> {
        let port: Int
        if let p = request.url.port {
            port = p
        } else if let scheme = request.url.scheme {
            port = scheme == "wss" ? 443 : 80
        } else {
            port = 80
        }
        return self.connect(host: request.url.host ?? "", port: port, uri: request.url.path, headers: request.headers) { socket in
            onUpgrade(socket)
        }
    }
}

extension WebSocketClient.Socket: WebSocket {
    public func onText(_ callback: @escaping (WebSocket, String) -> ()) {
        self.onText { (ws: WebSocketClient.Socket, data: String) in
            callback(ws, data)
        }
    }

    public func onBinary(_ callback: @escaping (WebSocket, ByteBuffer) -> ()) {
        self.onBinary { (ws: WebSocketClient.Socket, data: ByteBuffer) in
            callback(ws, data)
        }
    }

    public func onError(_ callback: @escaping (WebSocket, Error) -> ()) {
        self.onError { (ws: WebSocketClient.Socket, error: Error) in
            callback(ws, error)
        }
    }

    public func send(binary: ByteBuffer, promise: EventLoopPromise<Void>?) {
        var binary = binary
        self.send(binary: binary.readBytes(length: binary.readableBytes)!, promise: promise)
    }
}


private final class WebSocketClientUpgradeHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPClientRequestPart

    private let configuration: WebSocketClient.Configuration
    private let host: String
    private let uri: String
    private let upgradePromise: EventLoopPromise<Void>
    private let upgradePipelineHandler: (Channel, HTTPResponseHead) -> EventLoopFuture<Void>

    private enum State {
        case ready
        case awaitingResponseEnd(HTTPResponseHead)
    }

    private var state: State

    init(
        configuration: WebSocketClient.Configuration,
        host: String,
        uri: String,
        upgradePromise: EventLoopPromise<Void>,
        upgradePipelineHandler: @escaping (Channel, HTTPResponseHead) -> EventLoopFuture<Void>
    ) {
        self.configuration = configuration
        self.host = host
        self.uri = uri
        self.upgradePromise = upgradePromise
        self.upgradePipelineHandler = upgradePipelineHandler
        self.state = .ready
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)
        switch response {
        case .head(let head):
            self.state = .awaitingResponseEnd(head)
        case .body:
            // ignore bodies
            break
        case .end:
            switch self.state {
            case .awaitingResponseEnd(let head):
                self.upgrade(context: context, upgradeResponse: head).cascade(to: self.upgradePromise)
            case .ready:
                fatalError("Invalid response state")
            }
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
        let request = HTTPRequestHead(
            version: .init(major: 1, minor: 1),
            method: .GET,
            uri: self.uri.hasPrefix("/") ? self.uri : "/" + self.uri,
            headers: self.buildUpgradeRequest()
        )
        print(request)
        context.write(self.wrapOutboundOut(.head(request)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }

    func buildUpgradeRequest() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: "connection", value: "Upgrade")
        headers.add(name: "upgrade", value: "websocket")
        headers.add(name: "origin", value: "vapor/websocket")
        headers.add(name: "host", value: self.host)
        headers.add(name: "sec-websocket-version", value: "13")
        let bytes = [UInt8].random(count: 16)
        headers.add(name: "sec-websocket-key", value: Data(bytes).base64EncodedString())
        return headers
    }

    func upgrade(context: ChannelHandlerContext, upgradeResponse: HTTPResponseHead) -> EventLoopFuture<Void> {
        guard upgradeResponse.status == .switchingProtocols else {
            return context.eventLoop.makeFailedFuture(
                WebSocketClient.Error.invalidResponseStatus(upgradeResponse)
            )
        }

        return context.channel.pipeline.addHandlers([
            WebSocketFrameEncoder(),
            ByteToMessageHandler(WebSocketFrameDecoder(maxFrameSize: self.configuration.maxFrameSize))
        ]).flatMap {
            return context.pipeline.removeHandler(self)
        }.flatMap {
            return self.upgradePipelineHandler(context.channel, upgradeResponse)
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

private final class WebSocketClientHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    private var webSocket: WebSocketClient.Socket
    private var frameSequence: WebSocketFrameSequence?

    init(webSocket: WebSocketClient.Socket) {
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
