#if canImport(_Concurrency)
import NIOCore

public extension ViewRenderer {
    func render<E>(_ name: String, _ context: E) async throws -> View where E: Encodable {
        try await self.render(name, context).get()
    }

    func render(_ name: String) async throws -> View {
        try await self.render(name).get()
    }
}

extension View: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.headers.contentType = .html
        response.body = .init(buffer: self.data)
        return response
    }
}

#endif
