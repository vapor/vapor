import HTTP3
import Logging
import NIOCore
@_spi(HTTP3AsyncInterface) import NIOHTTP3
import NIOHTTPTypes
import NIOPosix
import NIOQUIC

func withTestHTTP3ClientConnection<Value>(
    ipAddress: String,
    port: Int,
    verificationConfiguration: VerificationConfiguration,
    logger: Logger,
    eventLoopGroup: any EventLoopGroup,
    body:
        sending (
            NIOAsyncChannelInboundStream<HTTPResponsePart>,
            NIOAsyncChannelOutboundWriter<HTTPRequestPart>
        ) async throws -> Value
) async throws -> Value {
    let (quicChannel, connectionCreator) = try await DatagramBootstrap(group: eventLoopGroup)
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .bind(host: "127.0.0.1", port: 0) { channel in
            channel.eventLoop.makeCompletedFuture {
                let (quicHandler, _) = try QUICHandler.makeHandlerAndConnectionMultiplexer(
                    channel: channel,
                    quicConfiguration: QUICConfiguration.client(
                        verificationConfiguration: verificationConfiguration,
                        applicationProtocols: ["h3"]
                    ),
                    logger: logger,
                    inboundStreamChannelInitializer: { channel -> EventLoopFuture<Never> in
                        channel.eventLoop.makeCompletedFuture { fatalError() }
                    }
                )
                try channel.pipeline.syncOperations.addHandler(quicHandler)
                let connectionCreator = TestHTTP3SingleConnectionCreator(
                    quicHandler: quicHandler,
                    connectionInitializer: { connectionChannel, streamCreator in
                        connectionChannel.eventLoop.makeCompletedFuture {
                            let h3Handler = HTTP3ConnectionHandler.client(
                                eventLoop: connectionChannel.eventLoop,
                                configuration: .defaults,
                                settings: HTTP3Settings(h3Datagram: true),
                                streamCreator: streamCreator,
                                logger: logger,
                                inboundPushStreamInitializer: { _ in fatalError() }
                            )
                            try connectionChannel.pipeline.syncOperations.addHandler(h3Handler)
                            return connectionChannel
                        }
                    },
                    inboundStreamInitializer: { streamChannel in
                        streamChannel.parent!.pipeline.handler(type: HTTP3ConnectionHandler<NIOQUIC.QUICStreamCreator>.self)
                            .flatMap { http3Handler in
                                http3Handler.inboundStreamReceived(streamChannel)
                            }
                    },
                    connectionState: ConnectionChannelState()
                )
                return (channel, NIOLoopBound(connectionCreator, eventLoop: channel.eventLoop))
            }
        }

    let multiplexer = HTTP3ClientConnectionMultiplexer<
        TestHTTP3SingleConnectionCreator,
        NIOQUIC.QUICStreamCreator
    >(
        eventLoop: quicChannel.eventLoop,
        createNewConnection: connectionCreator
    )

    let h3Connection = try await multiplexer.concurrencyView.createConnection(
        serverName: "127.0.0.1",
        remoteAddress: .init(ipAddress: ipAddress, port: port),
        inboundPushStreamInitializer: { _ in fatalError("Push streams not supported") }
    )

    let connectionChannel = try await quicChannel.eventLoop.flatSubmit { () -> EventLoopFuture<any Channel> in
        guard let connectionChannelFuture = connectionCreator.value.connectionState.future else {
            return quicChannel.eventLoop.makeFailedFuture(ChannelError.operationUnsupported)
        }
        return connectionChannelFuture
    }.get()

    do {
        let value = try await h3Connection.makeRequestStream().executeThenClose(body)

        // try await quicChannel.close()
        // try await connectionChannel.close()

        return value
    } catch {
        try? await quicChannel.close()
        try? await connectionChannel.close()

        throw error
    }
}

struct TestHTTP3SingleConnectionCreator: HTTP3ConnectionCreator {
    let quicHandler: QUICHandler
    let connectionInitializer: @Sendable (any Channel, NIOQUIC.QUICStreamCreator) -> EventLoopFuture<any Channel>
    let inboundStreamInitializer: @Sendable (any Channel) -> EventLoopFuture<Void>

    var connectionEstablished: Bool = false
    let connectionState: ConnectionChannelState

    func createNewConnection(
        serverName: String,
        remoteAddress: SocketAddress,
        connectionInitializer h3ConnectionInitializer: @escaping @Sendable (any Channel) -> EventLoopFuture<Void>
    ) -> EventLoopFuture<any Channel> {
        guard self.connectionEstablished == false else {
            fatalError("This connection creator only supports creating one connection.")
        }

        let connectionChannelFuture = self.quicHandler.createOutboundConnection(
            serverName: serverName,
            remoteAddress: remoteAddress,
            connectionInitializer: { [connectionInitializer] connectionChannel, streamCreator in
                connectionInitializer(connectionChannel, streamCreator).flatMap { newConnectionChannel in
                    h3ConnectionInitializer(newConnectionChannel)
                }
            },
            inboundStreamInitializer: self.inboundStreamInitializer
        ).map { connectionChannel, _ in
            connectionChannel
        }

        self.connectionState.future = connectionChannelFuture

        return connectionChannelFuture
    }
}

final class ConnectionChannelState: @unchecked Sendable {
    var future: EventLoopFuture<any Channel>?
}

extension HTTP3ClientConnection {
    /// Opens a single request stream on this connection wrapped in a `NIOAsyncChannel`.
    /// The stream is closed by the caller using `executeThenClose`.
    func makeRequestStream() async throws -> NIOAsyncChannel<HTTPResponsePart, HTTPRequestPart> {
        try await self.concurrencyView.createRequestStream {
            let streamChannel = $0.channel
            return streamChannel.eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<HTTPResponsePart, HTTPRequestPart>(
                    wrappingChannelSynchronously: streamChannel,
                    configuration: .init(isOutboundHalfClosureEnabled: true)
                )
            }
        }
    }
}
