import HTTPTypes
import NIOCore

/// Less verbose typealias for `HTTPResponse.Status`.
public typealias HTTPStatus = HTTPResponse.Status

extension HTTPStatus: ResponseEncodable {
    // See `ResponseEncodable.encodeResponse(for:)`.
    public func encodeResponse(for request: Request) async throws -> Response {
        Response(status: self)
    }
}
