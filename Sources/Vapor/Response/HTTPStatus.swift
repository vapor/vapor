/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encode(for req: RequestContext) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(status: self)
        return req.eventLoop.makeSucceededFuture(res)
    }
}
