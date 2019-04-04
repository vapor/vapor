/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `HTTPResponseEncodable`.
    public func encodeResponse(for req: HTTPRequest, using ctx: Context) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(status: self)
        return ctx.eventLoop.makeSucceededFuture(res)
    }
}
