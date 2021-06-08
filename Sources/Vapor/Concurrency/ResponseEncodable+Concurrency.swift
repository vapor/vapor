#if compiler(>=5.5)
import _NIOConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension ResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        try await self.encodeResponse(for: request).get()
    }
}

#endif
