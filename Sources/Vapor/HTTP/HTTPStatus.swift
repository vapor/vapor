import HTTPTypes
import NIOCore

/// Less verbose typealias for `HTTPResponse.Status`.
public typealias HTTPStatus = HTTPResponse.Status

extension HTTPStatus: AsyncResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) async throws -> Response {
        Response(status: self)
    }
}

extension HTTPStatus: Codable {
    public init(from decoder: Decoder) throws {
        let code = try decoder.singleValueContainer().decode(Int.self)
        self = .init(code: code)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
}
