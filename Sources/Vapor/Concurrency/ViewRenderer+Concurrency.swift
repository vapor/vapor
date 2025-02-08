import NIOCore

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
