#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension ResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        try await self.encodeResponse(for: request).get()
    }
}

#endif
