#if UnstableWebTransport

public import NIOCore
import NIOHTTPServer
import Synchronization

/// A single WebTransport session opened over an HTTP/3 connection.
public struct WebTransportSession: Sendable, ~Copyable {
    private let streamCreator: NIOHTTPServer.Connection.WebTransportStreamCreator
    private let requestContext: NIOHTTPServer.RequestContext

    /// An asynchronous sequence of unidirectional streams opened by the client.
    /// Each one can be used to read data from the client.
    public let incomingUnidirectionalStreams: AsyncStream<NIOAsyncChannel<ByteBuffer, Never>>
    /// An asynchronous sequence of bidirectional streams opened by the client.
    /// Each one can be used to read data from the client and write data back to it.
    public let incomingBidirectionalStreams: AsyncStream<NIOAsyncChannel<ByteBuffer, ByteBuffer>>

    init(
        streamCreator: NIOHTTPServer.Connection.WebTransportStreamCreator,
        requestContext: NIOHTTPServer.RequestContext,
        incomingUnidirectionalStreams: AsyncStream<NIOAsyncChannel<ByteBuffer, Never>>,
        incomingBidirectionalStreams: AsyncStream<NIOAsyncChannel<ByteBuffer, ByteBuffer>>
    ) {
        self.streamCreator = streamCreator
        self.requestContext = requestContext
        self.incomingUnidirectionalStreams = incomingUnidirectionalStreams
        self.incomingBidirectionalStreams = incomingBidirectionalStreams
    }

    /// Open a unidirectional stream that can be used to write to the client.
    ///
    /// - Parameter operation: The closure where writing operations are performed.
    ///
    /// - Returns: The value returned by the `operation` closure.
    public func withUnidirectionalStream<Value>(
        operation: (NIOAsyncChannelOutboundWriter<ByteBuffer>) async throws -> Value
    ) async throws -> Value {
        try await self.streamCreator.withUnidirectionalStream(requestContext: self.requestContext, operation: operation)
    }

    /// Open a bidirectional stream that can be used to read from and write to the client.
    ///
    /// - Parameter operation: The closure where reading and writing operations are performed.
    ///
    /// - Returns: The value returned by the `operation` closure.
    public func withBidirectionalStream<Value>(
        operation: (
            NIOAsyncChannelInboundStream<ByteBuffer>,
            NIOAsyncChannelOutboundWriter<ByteBuffer>
        ) async throws -> Value
    ) async throws -> Value {
        try await self.streamCreator.withBidirectionalStream(requestContext: self.requestContext, operation: operation)
    }
}

#endif
