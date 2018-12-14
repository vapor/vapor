/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequestContext) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(status: self)
        return req.eventLoop.makeSucceededFuture(result: res)
    }
}
