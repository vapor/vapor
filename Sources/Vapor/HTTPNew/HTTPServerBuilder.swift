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

import HTTPServerNew
import NIOCore
import Logging
import ServiceLifecycle

/// Build server that takes an HTTP responder
///
/// Used when building an ``Hummingbird/Application``. It delays the building
/// of the ``ServerChildChannel`` and ``Server`` until the HTTP responder has been built.
public struct HTTPServerBuilder: Sendable {
    /// build child channel from HTTP responder
    package let buildChildChannel: @Sendable (@escaping HTTPChannelHandler.Responder) throws -> any ServerChildChannel

    /// Initialize HTTPServerBuilder
    /// - Parameter build: closure building child channel from HTTP responder
    public init(_ build: @escaping @Sendable (@escaping HTTPChannelHandler.Responder) throws -> any ServerChildChannel) {
        self.buildChildChannel = build
    }

    ///  Build server
    /// - Parameters:
    ///   - configuration: Server configuration
    ///   - eventLoopGroup: EventLoopGroup used by server
    ///   - logger: Logger used by server
    ///   - responder: HTTP responder
    ///   - onServerRunning: Closure to run once server is up and running
    /// - Returns: Server Service
    public func buildServer(
        configuration: ServerConfiguration,
        eventLoopGroup: EventLoopGroup,
        logger: Logger,
        responder: @escaping HTTPChannelHandler.Responder,
        onServerRunning: (@Sendable (Channel) async -> Void)? = nil
    ) throws -> Service {
        let childChannel = try buildChildChannel(responder)
        return childChannel.server(configuration: configuration, onServerRunning: onServerRunning, eventLoopGroup: eventLoopGroup, logger: logger)
    }
}

extension HTTPServerBuilder {
    ///  Return a `HTTPServerBuilder` that will build a HTTP1 server
    ///
    /// Use in ``Hummingbird/Application`` initialization.
    /// ```
    /// let app = Application(
    ///     router: router,
    ///     server: .http1(configuration: .init(idleTimeout: .seconds(30)))
    /// )
    /// ```
    /// - Parameter configuration: HTTP1 channel configuration
    /// - Returns: HTTPServerBuilder builder
    public static func http1(
        configuration: HTTP1Channel.Configuration = .init()
    ) -> HTTPServerBuilder {
        .init { responder in
            HTTP1Channel(responder: responder, configuration: configuration)
        }
    }
}
