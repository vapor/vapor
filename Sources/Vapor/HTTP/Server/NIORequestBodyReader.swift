/// The server's concrete ``RequestBodyReader`` — a borrowed, non-escapable view onto the request body,
/// the mirror of ``NIOHTTPBodyWriter``. Lent only for a ``Request/Body/withReader(_:)`` closure;
/// being `~Escapable` it can't be stored, so "read the body twice" is a compile-time error. Each
/// ``read(_:)`` hands the next part out as a borrowed `Span<UInt8>`, copying nothing until user code keeps it.
struct NIORequestBodyReader: RequestBodyReader, ~Escapable {
    private let stream: RequestBodyStream

    @_lifetime(borrow scope)
    init(_ stream: RequestBodyStream, scope: borrowing RequestBodyReaderScope) {
        self.stream = stream
    }

    func read<R>(_ body: (Span<UInt8>, Bool) async throws -> R) async throws -> R {
        try await self.stream.read(body)
    }
}
