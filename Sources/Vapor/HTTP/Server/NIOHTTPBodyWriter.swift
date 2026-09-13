import NIOHTTPServer

/// Bridges Vapor's ``HTTPBodyWriter`` onto the server's move-only response writer.
///
/// Each chunk is copied into a `UniqueArray<UInt8>` and forwarded with `await`, so the transport's
/// backpressure (the socket/HTTP-2 flow-control window) propagates straight to the body-stream
/// closure — a fast producer suspends while a slow client catches up.
struct NIOHTTPBodyWriter: HTTPBodyWriter, ~Escapable {
    private let storage: NIOHTTPBodyWriterStorage

    @_lifetime(borrow scope)
    init(_ storage: NIOHTTPBodyWriterStorage, scope: borrowing HTTPBodyWriterScope) {
        self.storage = storage
    }

    func write(_ bytes: Span<UInt8>) async throws {
        try await self.storage.write(bytes)
    }

    func write(_ bytes: some Sequence<UInt8>) async throws {
        try await self.storage.write(bytes)
    }
}
