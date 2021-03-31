public struct View: ResponseEncodable {
    public var data: ByteBuffer

    public init(data: ByteBuffer) {
        self.data = data
    }

    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(byteBufferAllocator: request.byteBufferAllocator)
        response.headers.contentType = .html
        response.body = .init(buffer: self.data, byteBufferAllocator: request.byteBufferAllocator)
        return request.eventLoop.makeSucceededFuture(response)
    }
}
