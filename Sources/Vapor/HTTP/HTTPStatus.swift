/// Less verbose typealias for `HTTPResponseStatus`.
public typealias HTTPStatus = HTTPResponseStatus

extension HTTPStatus: ResponseEncodable {
    /// See `ResponseEncodable`.
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let response = Response(status: self)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

extension HTTPStatus: AbortError {
    public var status: HTTPResponseStatus {
        return self
    }
    
    public var reason: String {
        return self.reasonPhrase
    }
}
