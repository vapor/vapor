import NIOCore

public struct View: ResponseEncodable, Sendable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        response.responseBox.withLockedValue { box in
            box.headers.contentType = .html
            box.body = .init(buffer: self.data)
        }
        return response
    }
}
