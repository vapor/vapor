#if compiler(>=5.5) && canImport(_Concurrency)
import NIOCore

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
public extension ViewRenderer {
    func render<E>(_ name: String, _ context: E) async throws -> View where E: Encodable {
        try await self.render(name, context).get()
    }

    func render(_ name: String) async throws -> View {
        try await self.render(name).get()
    }
}

@available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
extension View: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response(byteBufferAllocator: request.byteBufferAllocator)
        response.headers.contentType = .html
        response.body = .init(buffer: self.data)
        return response
    }
}

#endif
