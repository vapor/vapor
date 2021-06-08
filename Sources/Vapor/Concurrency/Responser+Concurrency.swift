#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension Responder {
    public func respond(to request: Request) async throws -> Response {
        try await self.respond(to: request).get()
    }
}

#endif
