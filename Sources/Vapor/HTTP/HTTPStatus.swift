/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self)
        return request.eventLoop.makeSucceededFuture(response)
    }
}
