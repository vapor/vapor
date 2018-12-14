/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: HTTPResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: HTTPRequest) -> HTTPResponse {
        return HTTPResponse(status: self)
    }
}
