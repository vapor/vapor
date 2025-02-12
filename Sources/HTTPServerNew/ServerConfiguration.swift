//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

/// HTTP server configuration
public struct ServerConfiguration: Sendable {
    /// Bind address for server
    public let address: BindAddress
    /// Server name to return in "server" header
    public let serverName: String?
    /// Defines the maximum length for the queue of pending connections
    public let backlog: Int
    /// Allows socket to be bound to an address that is already in use.
    public let reuseAddress: Bool
    /// Object deciding on when we should accept new connection. Use ``MaximumAvailableConnections``
    /// to set the maximum allowed connections.
    ///
    /// If we are not accepting connections the requests will be added to the backlog until the
    /// server is accepting connections again. If the backlog fills up then the server will start
    /// refusing requests.
    public let availableConnectionsDelegate: AvailableConnectionsDelegate?
    #if canImport(Network)
    /// TLS options for NIO Transport services
    public let tlsOptions: TSTLSOptions
    #endif

    /// Initialize server configuration
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - availableConnectionsDelegate: Object deciding on when we should accept new connection. Use ``MaximumAvailableConnections``
    ///         to set the maximum allowed connections.
    public init(
        address: BindAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        availableConnectionsDelegate: AvailableConnectionsDelegate? = nil
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.availableConnectionsDelegate = availableConnectionsDelegate
        #if canImport(Network)
        self.tlsOptions = .none
        #endif
    }

    /// Initialize HTTP server configuration
    /// - Parameters:
    ///   - address: Bind address for server
    ///   - serverName: Server name to return in "server" header
    ///   - backlog: the maximum length for the queue of pending connections.  If a connection request arrives with the queue full,
    ///         the client may receive an error with an indication of ECONNREFUSE
    ///   - reuseAddress: Allows socket to be bound to an address that is already in use.
    ///   - availableConnectionsDelegate: Object deciding on when we should accept new connection. Use ``MaximumAvailableConnections``
    ///         to set the maximum allowed connections.
    ///   - tlsOptions: TLS options for when you are using NIOTransportServices
    #if canImport(Network)
    public init(
        address: BindAddress = .hostname(),
        serverName: String? = nil,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        availableConnectionsDelegate: AvailableConnectionsDelegate? = nil,
        tlsOptions: TSTLSOptions
    ) {
        self.address = address
        self.serverName = serverName
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.availableConnectionsDelegate = availableConnectionsDelegate
        self.tlsOptions = tlsOptions
    }
    #endif
}
