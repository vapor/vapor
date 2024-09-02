import NIOCore

public struct View: ResponseEncodable, Sendable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        reponse.headers.contentType = .html
        response.body = .init(buffer: self.data, byteBufferAllocator: request.byteBufferAllocator)
        return response
    }
}
