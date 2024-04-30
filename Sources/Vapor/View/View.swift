import NIOCore

public struct View: ResponseEncodable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response()
        response.responseBox.withLockedValue { box in
            box.headers.contentType = .html
            box.body = .init(buffer: self.data, byteBufferAllocator: request.byteBufferAllocator)
        }
        return request.eventLoop.makeSucceededFuture(response)
    }
}
