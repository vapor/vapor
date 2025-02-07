import NIOCore

extension ViewRenderer {
    public func render<E>(_ name: String, _ context: E) async throws -> View where E: Encodable {
        try await self.render(name, context).get()
    }

    public func render(_ name: String) async throws -> View {
        try await self.render(name).get()
    }
}

extension View: AsyncResponseEncodable {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.responseBox.withLockedValue { box in
            box.headers.contentType = .html
            box.body = .init(buffer: self.data)
        }
        return response
    }
}
