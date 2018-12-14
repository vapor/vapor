/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: HTTPResponseEncodable {
    /// See `ResponseEncodable`.
    public func encode(for req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(status: self)
        return req.channel!.eventLoop.makeSucceededFuture(result: res)
    }
}
