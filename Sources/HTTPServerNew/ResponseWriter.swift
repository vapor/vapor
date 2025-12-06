//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOCore
import NIOHTTPTypes

/// ResponseWriter that writes directly to AsyncChannel
public struct ResponseWriter: ~Copyable, Sendable {
    @usableFromInline
    let outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>

    public init(outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>) {
        self.outbound = outbound
    }

    /// Write HTTP head part and return ``ResponseBodyWriter`` to write response body
    ///
    /// - Parameter head: Response head
    /// - Returns: Response body writer used to write HTTP response body
    @inlinable
    public consuming func writeHead(_ head: HTTPResponse) async throws -> some ResponseBodyWriter {
        try await self.outbound.write(.head(head))
        return RootResponseBodyWriter(outbound: self.outbound)
    }

    /// Write Informational HTTP head part
    ///
    /// Calling this with a non informational HTTP response head will cause a precondition error
    /// - Parameter head: Informational response head
    @inlinable
    public func writeInformationalHead(_ head: HTTPResponse) async throws {
        precondition((100..<200).contains(head.status.code), "Informational HTTP responses require a status code in the range of 100 through 199")
        try await self.outbound.write(.head(head))
    }

    /// Write full HTTP response that doesn't include a body
    ///
    /// - Parameter head: Response head
    @inlinable
    public consuming func writeResponse(_ head: HTTPResponse) async throws {
        try await self.outbound.write(contentsOf: [.head(head), .end(nil)])
    }
}

/// ResponseBodyWriter that writes ByteBuffers to AsyncChannel outbound writer
@usableFromInline
struct RootResponseBodyWriter: Sendable, ResponseBodyWriter {
    typealias Out = HTTPResponsePart
    /// The components of a HTTP response from the view of a HTTP server.
    public typealias OutboundWriter = NIOAsyncChannelOutboundWriter<Out>

    @usableFromInline
    let outbound: OutboundWriter

    @usableFromInline
    init(outbound: OutboundWriter) {
        self.outbound = outbound
    }

    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    @inlinable
    func write(_ buffer: ByteBuffer) async throws {
        try await self.outbound.write(.body(buffer))
    }

    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    @inlinable
    func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        try await self.outbound.write(contentsOf: buffers.map { .body($0) })
    }

    /// Finish writing body
    /// - Parameter trailingHeaders: Any trailing headers you want to include at end
    @inlinable
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws {
        try await self.outbound.write(.end(trailingHeaders))
    }
}
