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
        onUpgrade: @escaping (WebSocket) -> ()
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
                    let webSocket = WebSocket(channel: channel)
                    return channel.pipeline.removeHandler(httpEncoder).flatMap {
                        return channel.pipeline.removeHandler(httpDecoder)
                    }.flatMap {
                        return webSocket.addHandler(to: channel.pipeline)
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
