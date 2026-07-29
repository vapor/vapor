import HTTPTypes
import NIOCore


extension HTTPResponse.Status: ResponseEncodable {
    // See `ResponseEncodable.encodeResponse(for:)`.
    public func encodeResponse(for request: Request) async throws -> Response {
        Response(status: self)
    }
}
