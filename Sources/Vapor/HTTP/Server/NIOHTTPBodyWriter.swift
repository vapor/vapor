import NIOHTTPServer

/// Bridges Vapor's ``HTTPBodyWriter`` onto the server's move-only response writer with backpressure support
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
