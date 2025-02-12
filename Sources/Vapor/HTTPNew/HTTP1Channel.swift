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

import HTTPTypes
import Logging
import NIOCore
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import HTTPServerNew

/// Child channel for processing HTTP1
public struct HTTP1Channel: ServerChildChannel, HTTPChannelHandler {
    public typealias Value = NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>

    /// HTTP1Channel configuration
    public struct Configuration: Sendable {
        /// Additional channel handlers to add to channel pipeline after HTTP part decoding and before HTTP request handling
        public var additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
        /// Time before closing an idle channel.
        public var idleTimeout: TimeAmount?

        ///  Initialize HTTP1Channel.Configuration
        /// - Parameters:
        ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline after HTTP part decoding and
        ///         before HTTP request processing
        ///   - idleTimeout: Time before closing an idle channel
        public init(
            additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
            idleTimeout: TimeAmount? = nil
        ) {
            self.additionalChannelHandlers = additionalChannelHandlers
            self.idleTimeout = idleTimeout
        }
    }

    ///  Initialize HTTP1Channel
    /// - Parameters:
    ///   - responder: Function returning a HTTP response for a HTTP request
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline after HTTP part decoding and
    ///         before HTTP request processing
    @available(*, deprecated, renamed: "HTTP1Channel(responder:configuration:)")
    public init(
        responder: @escaping HTTPChannelHandler.Responder,
        additionalChannelHandlers: @escaping @Sendable () -> [any RemovableChannelHandler]
    ) {
        self.configuration = .init(additionalChannelHandlers: additionalChannelHandlers())
        self.responder = responder
    }

    ///  Initialize HTTP1Channel
    /// - Parameters:
    ///   - responder: Function returning a HTTP response for a HTTP request
    ///   - configuration: HTTP1 channel configuration
    public init(
        responder: @escaping HTTPChannelHandler.Responder,
        configuration: Configuration = .init()
    ) {
        self.configuration = configuration
        self.responder = responder
    }

    /// Setup child channel for HTTP1
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: false,  // HTTP is pipelined by NIOAsyncChannel
                withErrorHandling: true,
                withOutboundHeaderValidation: false  // Swift HTTP Types are already doing this validation
            )
            try channel.pipeline.syncOperations.addHandler(HTTP1ToHTTPServerCodec(secure: false))
            try channel.pipeline.syncOperations.addHandlers(self.configuration.additionalChannelHandlers())
            if let idleTimeout = self.configuration.idleTimeout {
                try channel.pipeline.syncOperations.addHandler(IdleStateHandler(readTimeout: idleTimeout))
            }
            try channel.pipeline.syncOperations.addHandler(HTTPUserEventHandler(logger: logger))
            return try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: .init()
            )
        }
    }

    /// handle HTTP messages being passed down the channel pipeline
    /// - Parameters:
    ///   - asyncChannel: NIOAsyncChannel handling HTTP parts
    ///   - logger: Logger to use while processing messages
    @inlinable
    public func handle(
        value asyncChannel: NIOCore.NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>,
        logger: Logging.Logger
    ) async {
        await handleHTTP(asyncChannel: asyncChannel, logger: logger)
    }

    public let responder: HTTPChannelHandler.Responder
    public let configuration: Configuration
}

/// Extend NIOAsyncChannel to ServerChildChannelValue so it can be used in a ServerChildChannel
extension NIOAsyncChannel: ServerChildChannelValue {}
