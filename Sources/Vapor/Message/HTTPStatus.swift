/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(status: self)
        return request.eventLoop.makeSucceededFuture(res)
    }
}
