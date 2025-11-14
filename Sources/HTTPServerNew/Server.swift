//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOExtras
import NIOPosix
import ServiceLifecycle

#if canImport(Network)
import Network
import NIOTransportServices
#endif

/// HTTP server class
public actor HTTPServer<ChildChannel: ServerChildChannel>: Service {
    public typealias AsyncChildChannel = ChildChannel.Value
    public typealias AsyncServerChannel = NIOAsyncChannel<AsyncChildChannel, Never>
    enum State: CustomStringConvertible {
        case initial(
            childChannelSetup: ChildChannel,
            configuration: ServerConfiguration,
            onServerRunning: (@Sendable (any Channel) async -> Void)?
        )
        case starting
        case running(
            asyncChannel: AsyncServerChannel,
            quiescingHelper: ServerQuiescingHelper
        )
        case shuttingDown(shutdownPromise: EventLoopPromise<Void>)
        case shutdown

        var description: String {
            switch self {
            case .initial:
                return "initial"
            case .starting:
                return "starting"
            case .running:
                return "running"
            case .shuttingDown:
                return "shuttingDown"
            case .shutdown:
                return "shutdown"
            }
        }
    }

    var state: State {
        didSet { self.logger.info("Server State: \(self.state)") }
    }

    /// Logger used by Server
    public nonisolated let logger: Logger
    let eventLoopGroup: any EventLoopGroup

    /// HTTP server errors
    public enum Error: Swift.Error {
        case serverShuttingDown
        case serverShutdown
    }

    /// Initialize Server
    /// - Parameters:
    ///   - childChannelSetup: Server child channel
    ///   - configuration: Configuration for server
    ///   - onServerRunning: Closure to run once server is up and running
    ///   - eventLoopGroup: EventLoopGroup the server uses
    ///   - logger: Logger used by server
    public init(
        childChannelSetup: ChildChannel,
        configuration: ServerConfiguration,
        onServerRunning: (@Sendable (any Channel) async -> Void)? = nil,
        eventLoopGroup: any EventLoopGroup,
        logger: Logger
    ) {
        self.state = .initial(
            childChannelSetup: childChannelSetup,
            configuration: configuration,
            onServerRunning: onServerRunning
        )
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
    }

    public func run() async throws {
        self.logger.info("Running", metadata: ["state": "\(self.state)"])
        switch self.state {
        case .initial(let childChannelSetup, let configuration, let onServerRunning):
            self.state = .starting

            do {
                let (asyncChannel, quiescingHelper) = try await self.makeServer(
                    childChannelSetup: childChannelSetup,
                    configuration: configuration
                )

                // We have to check our state again since we just awaited on the line above
                switch self.state {
                case .initial, .running:
                    fatalError("We should only be running once")

                case .starting:
                    self.state = .running(asyncChannel: asyncChannel, quiescingHelper: quiescingHelper)

                    await withGracefulShutdownHandler {
                        await onServerRunning?(asyncChannel.channel)

                        let logger = self.logger
                        // We can now start to handle our work.
                        await withDiscardingTaskGroup { group in
                            do {
                                try await asyncChannel.executeThenClose { inbound in
                                    for try await childChannel in inbound {
                                        group.addTask {
                                            await childChannelSetup.handle(value: childChannel, logger: logger)
                                        }
                                    }
                                }
                            } catch {
                                logger.error("Waiting on child channel: \(error)")
                            }
                        }
                    } onGracefulShutdown: {
                        Task {
                            do {
                                try await self.shutdownGracefully()
                            } catch {
                                self.logger.error("Server shutdown error: \(error)")
                            }
                        }
                    }

                case .shuttingDown, .shutdown:
                    self.logger.info("Shutting down")
                    try await asyncChannel.channel.close()
                }
            } catch {
                self.state = .shutdown
                throw error
            }

        case .starting, .running:
            fatalError("Run should only be called once")

        case .shuttingDown:
            throw Error.serverShuttingDown

        case .shutdown:
            throw Error.serverShutdown
        }
    }

    /// Stop HTTP server
    public func shutdownGracefully() async throws {
        switch self.state {
        case .initial, .starting:
            self.state = .shutdown

        case .running(let channel, let quiescingHelper):
            let shutdownPromise = channel.channel.eventLoop.makePromise(of: Void.self)
            self.state = .shuttingDown(shutdownPromise: shutdownPromise)
            quiescingHelper.initiateShutdown(promise: shutdownPromise)
            try await shutdownPromise.futureResult.get()

            // We need to check the state here again since we just awaited above
            switch self.state {
            case .initial, .starting, .running, .shutdown:
                fatalError("Unexpected state \(self.state)")

            case .shuttingDown:
                self.state = .shutdown
            }

        case .shuttingDown(let shutdownPromise):
            // We are just going to queue up behind the current graceful shutdown
            try await shutdownPromise.futureResult.get()

        case .shutdown:
            return
        }
    }

    /// Start server
    /// - Parameter responder: Object that provides responses to requests sent to the server
    /// - Returns: EventLoopFuture that is fulfilled when server has started
    nonisolated func makeServer(
        childChannelSetup: ChildChannel,
        configuration: ServerConfiguration
    ) async throws -> (AsyncServerChannel, ServerQuiescingHelper) {
        var bootstrap: any ServerBootstrapProtocol
        #if canImport(Network)
        if let tsBootstrap = self.createTSBootstrap(configuration: configuration) {
            bootstrap = tsBootstrap
        } else {
            #if os(iOS) || os(tvOS)
            self.logger.warning(
                "Running BSD sockets on iOS or tvOS is not recommended. Please use NIOTSEventLoopGroup, to run with the Network framework"
            )
            #endif
            if configuration.tlsOptions.options != nil {
                self.logger.warning(
                    "tlsOptions set in Configuration will not be applied to a BSD sockets server. Please use NIOTSEventLoopGroup, to run with the Network framework"
                )
            }
            bootstrap = self.createSocketsBootstrap(configuration: configuration)
        }
        #else
        bootstrap = self.createSocketsBootstrap(
            configuration: configuration
        )
        #endif

        let quiescingHelper = ServerQuiescingHelper(group: self.eventLoopGroup)
        bootstrap = bootstrap.serverChannelInitializer { channel in
            channel.eventLoop.makeCompletedFuture {
                if let availableConnectionsDelegate = configuration.availableConnectionsDelegate {
                    let handler = availableConnectionsDelegate.availableConnectionsChannelHandler
                    try channel.pipeline.syncOperations.addHandler(handler)
                }
                try channel.pipeline.syncOperations.addHandler(quiescingHelper.makeServerChannelHandler(channel: channel))
            }
        }

        do {
            switch configuration.address.value {
            case .hostname(let host, let port):
                let asyncChannel = try await bootstrap.bind(
                    host: host,
                    port: port,
                    serverBackPressureStrategy: nil
                ) { channel in
                    childChannelSetup.setup(
                        channel: channel,
                        logger: self.logger
                    )
                }
                self.logger.info("Server started and listening on \(host):\(asyncChannel.channel.localAddress?.port ?? port)")
                return (asyncChannel, quiescingHelper)

            case .unixDomainSocket(let path):
                let asyncChannel = try await bootstrap.bind(
                    unixDomainSocketPath: path,
                    cleanupExistingSocketFile: false,
                    serverBackPressureStrategy: nil
                ) { channel in
                    childChannelSetup.setup(
                        channel: channel,
                        logger: self.logger
                    )
                }
                self.logger.info("Server started and listening on socket path \(path)")
                return (asyncChannel, quiescingHelper)

            #if canImport(Network)
            case .nwEndpoint(let endpoint):
                guard let tsBootstrap = bootstrap as? NIOTSListenerBootstrap else {
                    preconditionFailure("Binding to a NWEndpoint is not available for ServerBootstrap. Please use NIOTSListenerBootstrap.")
                }
                let asyncChannel = try await tsBootstrap.bind(
                    endpoint: endpoint,
                    serverBackPressureStrategy: nil
                ) { channel in
                    childChannelSetup.setup(
                        channel: channel,
                        logger: self.logger
                    )
                }
                self.logger.info("Server started and listening on endpoint")
                return (asyncChannel, quiescingHelper)
            #endif
            }
        } catch {
            // should we close the channel here
            throw error
        }
    }

    /// create a BSD sockets based bootstrap
    private nonisolated func createSocketsBootstrap(
        configuration: ServerConfiguration
    ) -> ServerBootstrap {
        ServerBootstrap(group: self.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: numericCast(configuration.backlog))
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
    }

    #if canImport(Network)
    /// create a NIOTransportServices bootstrap using Network.framework
    private nonisolated func createTSBootstrap(
        configuration: ServerConfiguration
    ) -> NIOTSListenerBootstrap? {
        guard
            let bootstrap = NIOTSListenerBootstrap(validatingGroup: self.eventLoopGroup)?
                .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
                // Set the handlers that are applied to the accepted Channels
                .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
                .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        else {
            return nil
        }

        if let tlsOptions = configuration.tlsOptions.options {
            return bootstrap.tlsOptions(tlsOptions)
        }
        return bootstrap
    }
    #endif
}

/// Protocol for bootstrap.
protocol ServerBootstrapProtocol {
    /// Initialize the `ServerSocketChannel` with `initializer`. The most common task in initializer is to add
    /// `ChannelHandler`s to the `ChannelPipeline`.
    ///
    /// The `ServerSocketChannel` uses the accepted `Channel`s as inbound messages.
    ///
    /// - note: To set the initializer for the accepted `SocketChannel`s, look at `ServerBootstrap.childChannelInitializer`.
    ///
    /// - parameters:
    ///     - initializer: A closure that initializes the provided `Channel`.
    func serverChannelInitializer(_ initializer: @escaping @Sendable (any Channel) -> EventLoopFuture<Void>) -> Self

    func bind<Output: Sendable>(
        host: String,
        port: Int,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (any Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never>

    func bind<Output: Sendable>(
        unixDomainSocketPath: String,
        cleanupExistingSocketFile: Bool,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (any Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never>
}

// Extend both `ServerBootstrap` and `NIOTSListenerBootstrap` to conform to `ServerBootstrapProtocol`
extension ServerBootstrap: ServerBootstrapProtocol {}

#if canImport(Network)
extension NIOTSListenerBootstrap: ServerBootstrapProtocol {
    // need to be able to extend `NIOTSListenerBootstrap` to conform to `ServerBootstrapProtocol`
    // before we can use TransportServices
    func bind<Output: Sendable>(
        unixDomainSocketPath: String,
        cleanupExistingSocketFile: Bool,
        serverBackPressureStrategy: NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark?,
        childChannelInitializer: @escaping @Sendable (any Channel) -> EventLoopFuture<Output>
    ) async throws -> NIOAsyncChannel<Output, Never> {
        preconditionFailure("Binding to a unixDomainSocketPath is currently not available with NIOTSListenerBootstrap.")
    }
}
#endif

extension HTTPServer: CustomStringConvertible {
    public nonisolated var description: String {
        "Vapor"
    }
}
