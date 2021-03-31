/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self, byteBufferAllocator: request.byteBufferAllocator)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension HTTPStatus: Codable {
    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(Int.self)
        self = .init(statusCode: code)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}
