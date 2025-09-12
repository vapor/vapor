import NIOHTTP1
import NIOCore

/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

#if compiler(>=6.1)
extension HTTPStatus: @retroactive Decodable {}
extension HTTPStatus: @retroactive Encodable {}
#else
extension HTTPStatus: Codable {}
#endif

extension HTTPStatus {
    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(Int.self)
        self = .init(statusCode: code)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}
