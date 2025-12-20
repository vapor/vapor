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

#if canImport(Network)
import Network
import NIOTransportServices
#endif

/// Address to bind server to
public struct BindAddress: Sendable, Equatable {
    enum _Internal: Equatable {
        case hostname(_ host: String = "127.0.0.1", port: Int = 8080)
        case unixDomainSocket(path: String)
        #if canImport(Network)
        case nwEndpoint(NWEndpoint)
        #endif
    }

    let value: _Internal
    init(_ value: _Internal) {
        self.value = value
    }

    // Address define by host and port
    public static func hostname(_ host: String = "127.0.0.1", port: Int = 8080) -> Self { .init(.hostname(host, port: port)) }
    // Address defined by unix domain socket
    public static func unixDomainSocket(path: String) -> Self { .init(.unixDomainSocket(path: path)) }
    #if canImport(Network)
    // Address defined by NWEndpoint
    public static func nwEndpoint(_ endpoint: NWEndpoint) -> Self { .init(.nwEndpoint(endpoint)) }
    #endif
}
